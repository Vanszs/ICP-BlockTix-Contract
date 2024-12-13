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
  

  
});
