const { expectEvent, expectRevert, time } = require('@openzeppelin/test-helpers');
const MotokoShinkai = artifacts.require("MotokoShinkai");
const TestToken = artifacts.require("TestToken");

contract("MotokoShinkai", accounts => {
  const [owner, user1, blacklistedUser, creator] = accounts;
  let eventId;

  beforeEach(async () => {
    this.token = await TestToken.new();
    this.motoko = await MotokoShinkai.new(this.token.address);

    await this.motoko.addWhitelistedCreator(creator, { from: owner });

    const receipt = await this.motoko.createEvent(
      "Test Event",
      (await time.latest()).addn(3600), // Event starts in 1 hour
      50, // Price in USD
      10, // Capacity
      { from: creator }
    );

    eventId = receipt.logs[0].args.eventId.toString(); // Save eventId as string

    await this.token.transfer(user1, web3.utils.toWei("1000", "ether"), { from: owner });
    await this.token.approve(this.motoko.address, web3.utils.toWei("50", "ether"), { from: user1 });
  });

  it("should create an event", async () => {
    const receipt = await this.motoko.createEvent("Another Event", (await time.latest()) + 7200, 100, 20, { from: creator });
    expectEvent(receipt, "EventCreated", { creator });
  });


  it("should allow buying ticket with ETH", async () => {

    const eventDetails = await this.motoko.events(eventId);
    const priceUSDFromEvent = Number(eventDetails.priceUSD.toString());
  
    const ETH_TO_USD_RATE = 3000;
    const ADMIN_FEE_PERCENTAGE = 10;
  
    const priceInWeiBN = web3.utils.toBN(priceUSDFromEvent)
      .mul(web3.utils.toBN(web3.utils.toWei('1', 'ether')))
      .div(web3.utils.toBN(ETH_TO_USD_RATE));
  
    // Hitung admin fee
    const adminFeeBN = priceInWeiBN.mul(web3.utils.toBN(ADMIN_FEE_PERCENTAGE)).div(web3.utils.toBN(100));
    const expectedBalanceETHBN = priceInWeiBN.sub(adminFeeBN);
  
    // Beli tiket dengan ETH
    const receipt = await this.motoko.buyTicketWithETH(eventId, {
      from: user1,
      value: priceInWeiBN.toString()
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
      const ticketPrice = web3.utils.toWei("0.0167", "ether");
      // Beli tiket
      await this.motoko.buyTicketWithETH(eventId, { from: user1, value: ticketPrice });
      const eventDetails = await this.motoko.events(eventId);
  
      await time.increaseTo((await time.latest()).addn(3700));

      const initialBalance = web3.utils.toBN(await web3.eth.getBalance(creator));
      const receipt = await this.motoko.withdrawEventFunds(eventId, { from: creator });

      expectEvent(receipt, "FundsWithdrawn", { eventId: eventId, recipient: creator });

      const finalBalance = web3.utils.toBN(await web3.eth.getBalance(creator));
      assert(finalBalance.gt(initialBalance), "Creator balance should increase after withdrawal");
    });

  it("should not allow withdrawal before the event ends", async () => {
    await expectRevert(
      this.motoko.withdrawEventFunds(eventId, { from: creator }),
      "Event not yet ended"
    );
  });

  it("should not allow creating an event with zero capacity", async () => {
    await expectRevert(
      this.motoko.createEvent(
        "Zero Capacity Event",
        (await time.latest()).addn(3600),
        50,
        0,
        { from: creator }
      ),
      "Capacity must be greater than 0"
    );
  });

  it("should not allow creating an event with past date", async () => {
    await expectRevert(
      this.motoko.createEvent(
        "Past Event",
        (await time.latest()).subn(3600),
        50,
        10,
        { from: creator }
      ),
      "Event date must be in the future"
    );
  });

  it("should not allow buying ticket after event starts", async () => {
    await time.increaseTo((await time.latest()).addn(3700)); // Move time forward
    await expectRevert(
      this.motoko.buyTicketWithETH(eventId, {
        from: user1,
        value: web3.utils.toWei("0.0167", "ether"),
      }),
      "Event already started"
    );
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

  it("should not allow blacklisted users to buy tickets", async () => {
    await this.motoko.updateBlacklist(blacklistedUser, true, { from: owner });

    await expectRevert(
      this.motoko.buyTicketWithETH(eventId, {
        from: blacklistedUser,
        value: web3.utils.toWei("0.0167", "ether"),
      }),
      "Address is blacklisted"
    );
  });

  it("should allow updating an event by creator", async () => {
    const newDate = (await time.latest()).addn(7200); // 2 hours from now
    const newPrice = 100; // New price in USD
    const newCapacity = 20; // New capacity
  
    const receipt = await this.motoko.editEvent(eventId, newDate, newPrice, newCapacity, { from: creator });
    expectEvent(receipt, "EventUpdated", {
      eventId: eventId,
      newDate: newDate.toString(),
      newPriceUSD: newPrice.toString(),
      newCapacity: newCapacity.toString(),
    });
  
    const updatedEvent = await this.motoko.events(eventId);
    assert.equal(updatedEvent.date.toString(), newDate.toString(), "Event date should be updated");
    assert.equal(updatedEvent.priceUSD.toString(), newPrice.toString(), "Event price should be updated");
    assert.equal(updatedEvent.capacity.toString(), newCapacity.toString(), "Event capacity should be updated");
  });
  
  it("should allow admin to withdraw fees", async () => {
    // Tambahkan token ke kontrak sebelum membeli tiket
    await this.token.transfer(this.motoko.address, web3.utils.toWei("50", "ether"), { from: owner });
  
    const ticketPrice = web3.utils.toWei("0.0167", "ether");
    await this.motoko.buyTicketWithETH(eventId, { from: user1, value: ticketPrice });
  
    const adminInitialBalance = web3.utils.toBN(await web3.eth.getBalance(owner));
  
    const receipt = await this.motoko.withdrawAdminFee({ from: owner });
    expectEvent(receipt, "AdminFeeWithdrawn", { admin: owner });
  
    const adminFinalBalance = web3.utils.toBN(await web3.eth.getBalance(owner));
    assert(adminFinalBalance.gt(adminInitialBalance), "Admin balance should increase after fee withdrawal");

  });
  
  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////



it("should not allow non-creator to withdraw event funds", async () => {
  // Non-creator mencoba menarik dana
  await expectRevert(
    this.motoko.withdrawEventFunds(eventId, { from: user1 }),
    "Only the creator can perform this action"
  );
});
  

it("should not allow withdrawal if event balance is zero", async () => {
  await time.increaseTo((await time.latest()).addn(3601));
  await expectRevert(
    this.motoko.withdrawEventFunds(eventId, { from: creator }),
    "No funds to withdraw"
  );
});


it("should not allow buying ticket with incorrect ETH amount", async () => {
  // Coba membeli tiket dengan ETH kurang dari harga
  await expectRevert(
    this.motoko.buyTicketWithETH(eventId, { from: user1, value: web3.utils.toWei("0.01", "ether") }),
    "Insufficient ETH sent"
  );
});
  
  
});