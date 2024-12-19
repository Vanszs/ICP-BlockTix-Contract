const { expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');
const MotokoShinkai = artifacts.require("MotokoShinkai");
const TestToken = artifacts.require("TestToken");

contract("MotokoShinkai", accounts => {
  const [owner, user1] = accounts;
  let eventId;

  beforeEach(async () => {
    this.token = await TestToken.new();
    this.motoko = await MotokoShinkai.new(this.token.address);
    await this.token.transfer(user1, web3.utils.toWei("1000", "ether"), { from: owner });
    await this.token.approve(this.motoko.address, web3.utils.toWei("50", "ether"), { from: user1 });

    // Membuat event sebelum setiap test
    const receipt = await this.motoko.createEvent(
      "Test Event",
      (await time.latest()).addn(3600), // Event dimulai dalam 1 jam
      50, // Harga tiket dalam USD
      10, // Kapasitas event
      { from: owner }
    );

    eventId = receipt.logs[0].args.eventId.toString(); // Simpan eventId sebagai string
  });

  it("should create an event", async () => {
    const receipt = await this.motoko.createEvent("Another Event", (await time.latest()) + 7200, 100, 20, { from: owner });
    expectEvent(receipt, "EventCreated", { eventId: "1" });
  });

  it("should allow buying ticket with ETH", async () => {
    const receipt = await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"), // Harga tiket dalam ETH
    });

    expectEvent(receipt, "TicketPurchased", {
      eventId: eventId,
      buyer: user1,
    });
  });

  it("should buy ticket with token", async () => {
    const receipt = await this.motoko.buyTicketWithToken(eventId, { from: user1 });
    expectEvent(receipt, "TicketPurchased", { eventId: eventId, buyer: user1 });
  });

  it("should allow the organizer to withdraw ETH after the event ends", async () => {
    // Membuat event dengan tanggal berakhir 1 jam ke depan
    const eventEndTime = (await time.latest()).addn(3600); // Event selesai dalam 1 jam
    const createReceipt = await this.motoko.createEvent(
        "Withdraw Test Event",
        eventEndTime.toString(), // Menggunakan `eventEndTime` sebagai tanggal event
        50, // Harga dalam USD
        10, // Kapasitas
        { from: owner }
    );
    const eventId = createReceipt.logs[0].args.eventId.toString();

    // Membeli tiket
    await this.motoko.buyTicketWithETH(eventId, {
        from: user1,
        value: web3.utils.toWei("0.0167", "ether"), // Harga tiket dalam ETH
    });

    // Fast-forward waktu ke setelah event selesai
    await time.increaseTo(eventEndTime.addn(1)); // Geser waktu ke 1 detik setelah `eventEndTime`

    // Tarik dana
    const initialBalance = web3.utils.toBN(await web3.eth.getBalance(owner));
    const receipt = await this.motoko.withdrawFunds(eventId, { from: owner });

    // Pastikan event `FundsWithdrawn` terjadi
    expectEvent(receipt, "FundsWithdrawn", {
        eventId: eventId,
        recipient: owner,
    });

    // Periksa saldo setelah penarikan
    const finalBalance = web3.utils.toBN(await web3.eth.getBalance(owner));
    assert(finalBalance.gt(initialBalance), "Balance should increase after withdrawal");
});



  it("should not allow withdrawal before event ends", async () => {
    await expectRevert(
      this.motoko.withdrawFunds(eventId, { from: owner }),
      "Event not yet ended"
    );
  });



  ////////////////////////////////////////////////////////////

  it("should not allow creating an event with zero capacity", async () => {
    await expectRevert(
      this.motoko.createEvent(
        "Zero Capacity Event",
        (await time.latest()).addn(3600), // Event dimulai dalam 1 jam
        50, // Harga tiket dalam USD
        0, // Kapasitas event = 0
        { from: owner }
      ),
      "Capacity must be greater than 0"
    );
  });

  it("should not allow creating an event with past date", async () => {
    await expectRevert(
      this.motoko.createEvent(
        "Past Event",
        (await time.latest()).subn(3600), // Event dimulai 1 jam di masa lalu
        50, // Harga tiket dalam USD
        10, // Kapasitas event
        { from: owner }
      ),
      "Event date must be in the future"
    );
  });

  it("should not allow buying ticket after event starts", async () => {
    // Fast-forward waktu ke setelah event dimulai
    await time.increaseTo((await time.latest()).addn(3700)); // 1 jam 10 menit

    await expectRevert(
      this.motoko.buyTicketWithETH(eventId, {
        from: user1,
        value: web3.utils.toWei("0.0167", "ether"),
      }),
      "Event already started"
    );
  });

  it("should refund excess ETH sent", async () => {
    const initialBalance = web3.utils.toBN(await web3.eth.getBalance(user1));

    const receipt = await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: web3.utils.toWei("0.02", "ether"), // Mengirim lebih banyak dari harga tiket
    });

    expectEvent(receipt, "TicketPurchased", {
      eventId: eventId,
      buyer: user1,
    });

    const finalBalance = web3.utils.toBN(await web3.eth.getBalance(user1));
    const priceInWei = web3.utils.toBN((50 * 1e18) / 3000); // Harga tiket dalam Wei
    assert(initialBalance.sub(finalBalance).lt(priceInWei.add(web3.utils.toBN(web3.utils.toWei("0.002", "ether")))));
  });

  it("should not allow buying ticket if capacity is full", async () => {
    for (let i = 0; i < 10; i++) {
      await this.motoko.buyTicketWithETH(eventId, {
        from: user1,
        value: web3.utils.toWei("0.0167", "ether"),
      });
    }

    await expectRevert(
      this.motoko.buyTicketWithETH(eventId, {
        from: user1,
        value: web3.utils.toWei("0.0167", "ether"),
      }),
      "Tickets sold out"
    );
  });

  it("should record attendees correctly", async () => {
    // Membeli tiket
    await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });
  
    // Ambil daftar attendees menggunakan fungsi getter
    const attendees = await this.motoko.getEventAttendees(eventId);
  
    // Pastikan user1 terdaftar sebagai attendee
    assert(attendees.includes(user1), "Attendee not recorded correctly");
  });

    // ----------------------------------------------------------------
  // TESTS FOR IDENTIFIED ISSUES / KEKURANGAN
  // ----------------------------------------------------------------

  it("should allow anyone to create an event (no owner restriction)", async () => {
    // Mencoba membuat event dari user1 (bukan owner)
    const receipt = await this.motoko.createEvent(
      "User1's Event",
      (await time.latest()).addn(3600),
      50,
      10,
      { from: user1 }
    );
    // Jika event berhasil dibuat, ini menandakan tidak ada pembatasan hanya owner yang bisa membuat event.
    expectEvent(receipt, "EventCreated");
  });

  it("should allow a non-creator to withdraw funds after event ends (no access control on withdrawal)", async () => {
    // Buat event dari owner
    const eventEndTime = (await time.latest()).addn(3600);
    const createReceipt = await this.motoko.createEvent(
      "No Access Control Event",
      eventEndTime.toString(),
      50,
      10,
      { from: owner }
    );
    const newEventId = createReceipt.logs[0].args.eventId.toString();

    // Beli tiket dengan ETH oleh user1
    await this.motoko.buyTicketWithETH(newEventId, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });

    // Majukan waktu melewati event end time
    await time.increaseTo(eventEndTime.addn(1));

    // Sekarang user1 (bukan creator event, karena creator adalah owner) mencoba tarik dana
    const initialBalanceUser1 = web3.utils.toBN(await web3.eth.getBalance(user1));
    const receipt = await this.motoko.withdrawFunds(newEventId, { from: user1 });
    expectEvent(receipt, "FundsWithdrawn", {
      eventId: newEventId,
      recipient: user1,
    });

    const finalBalanceUser1 = web3.utils.toBN(await web3.eth.getBalance(user1));
    assert(finalBalanceUser1.gt(initialBalanceUser1), "User1 berhasil menarik dana padahal bukan pembuat event");
  });

  it("should mix funds of different events (no fund segregation)", async () => {
    // Buat dua event berbeda
    const eventEndTime1 = (await time.latest()).addn(3600);
    const createReceipt1 = await this.motoko.createEvent(
      "Event One",
      eventEndTime1.toString(),
      50,
      10,
      { from: owner }
    );
    const eventIdOne = createReceipt1.logs[0].args.eventId.toString();

    const eventEndTime2 = (await time.latest()).addn(7200);
    const createReceipt2 = await this.motoko.createEvent(
      "Event Two",
      eventEndTime2.toString(),
      50,
      10,
      { from: owner }
    );
    const eventIdTwo = createReceipt2.logs[0].args.eventId.toString();

    // Beli tiket event one
    await this.motoko.buyTicketWithETH(eventIdOne, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });

    // Beli tiket event two
    await this.motoko.buyTicketWithETH(eventIdTwo, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });

    // Majukan waktu ke setelah event one berakhir, tapi sebelum event two berakhir
    await time.increaseTo(eventEndTime1.addn(10));

    // Tarik dana dari event one, harusnya hanya dana event one yang ditarik
    const initialBalanceOwner = web3.utils.toBN(await web3.eth.getBalance(owner));
    const receipt = await this.motoko.withdrawFunds(eventIdOne, { from: owner });
    expectEvent(receipt, "FundsWithdrawn", {
      eventId: eventIdOne,
      recipient: owner,
    });
    const finalBalanceOwner = web3.utils.toBN(await web3.eth.getBalance(owner));
    assert(finalBalanceOwner.gt(initialBalanceOwner), "Owner harusnya mendapat dana dari event one");

    // Sekarang cek apakah ada dana tersisa untuk event two (idealnya event two punya dana sendiri dan belum berakhir)
    // Pada kontrak ini tidak ada pemisahan, sehingga penarikan event one juga mengosongkan kontrak.
    const contractBalance = web3.utils.toBN(await web3.eth.getBalance(this.motoko.address));
    assert(contractBalance.eq(web3.utils.toBN("0")), "Kontrak tidak lagi punya dana, dana event two ikut habis");
  });

  it("should not provide any function to withdraw tokens collected (no token withdrawal function)", async () => {
    // Beli tiket event awal dengan token
    await this.motoko.buyTicketWithToken(eventId, { from: user1 });

    // Coba panggil fungsi yang seharusnya menarik token. Fungsi ini tidak ada.
    // Kami coba dengan cara memanggil fungsi withdrawFunds (ETH), yang jelas tidak mengembalikan token.
    // Karena tidak ada fungsi khusus untuk menarik token, kami hanya bisa membuktikan bahwa token tetap di kontrak.

    // Cek saldo token kontrak dan owner
    const contractTokenBalance = await this.token.balanceOf(this.motoko.address);
    assert(contractTokenBalance.gt(web3.utils.toBN("0")), "Kontrak memiliki saldo token");

    // Tidak ada fungsi withdraw token, jadi kita hanya tunjukkan bahwa token tetap tertahan
    // Test ini hanya membuktikan kekurangan, bukan kegagalan.   
  });

  it("should allow overpayment with tokens without refund (no excess token refund mechanism)", async () => {
    // Menaikkan allowance untuk user1 agar bisa transfer lebih dari harga tiket
    await this.token.approve(this.motoko.address, web3.utils.toWei("100", "ether"), { from: user1 });

    // Harga tiket dalam USD: 50 USD => 50 * 10^6 = 50.000000 token unit (asumsi 6 desimal)
    // tapi token ini mungkin 18 desimal, kita hanya tunjukkan test yang overpay 
    await this.motoko.buyTicketWithToken(eventId, { from: user1 });

    // Test ini tidak revert. Artinya user1 bisa memberi allowance lebih besar, dan kontrak akan ambil token sesuai price.
    // Tidak ada kembalian token. Sekali lagi, ini menunjukkan kekurangan, bukan kegagalan test.
  });

  // Test ini hanya menunjukkan bahwa tidak ada parameter untuk beli multiple tiket dalam satu panggilan
  // Meski ini bukan bug yang menyebabkan revert, hanya menunjukkan bahwa fitur terbatas
  it("should only buy one ticket at a time (no batch purchase)", async () => {
    // Disini kita hanya menegaskan bahwa fungsi buyTicketWithETH/Token tidak menerima jumlah tiket.
    // Pengujian ini mungkin tidak menghasilkan revert, tapi menunjukkan kekurangan fitur.
    // Untuk mencoba "multiple", kita bisa panggil fungsi dua kali dan melihat bahwa ia membeli dua tiket terpisah.
    await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });
    await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: web3.utils.toWei("0.0167", "ether"),
    });
    // Dua pembelian terpisah menandakan tidak ada cara beli multiple tiket sekali jalan.
    // Test ini lulus menunjukkan tidak ada kesalahan teknis, tapi meng-highlight kekurangan fitur.
  });

  // Menguji event dengan harga statis terhadap fluktuasi - ini sulit divalidasi dalam test statis.
  // Kita hanya menunjukkan bahwa ETH_TO_USD_RATE adalah konstan dan tidak bisa diubah.
  it("should have a static ETH to USD rate (no dynamic pricing)", async () => {
    const rate = await this.motoko.ETH_TO_USD_RATE();
    assert(rate.eq(web3.utils.toBN("3000")), "ETH to USD rate is static and cannot be changed");
    // Test ini menunjukkan kekurangan: harga statis.
  });

  

  
});
