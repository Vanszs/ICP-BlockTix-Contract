// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MotokoShinkai is Ownable, ReentrancyGuard {
    uint256 public constant ETH_TO_USD_RATE = 3000; // Fixed rate: 1 ETH = 3000 USD (6 desimal)
    uint256 public constant USD_DECIMALS = 6; // Harga dalam USD dengan 6 desimal (misalnya $10.00 = 1000000)

    struct Event {
        string name;
        uint256 date; // Timestamp
        uint256 priceUSD; // Harga tiket dalam USD (6 desimal)
        uint256 capacity; // Kapasitas tiket
        uint256 ticketsSold; // Jumlah tiket terjual
        bool isActive; // Status event
    }

    uint256 public nextEventId;
    mapping(uint256 => Event) public events;
    mapping(uint256 => address[]) public eventAttendees;

    event EventCreated(uint256 eventId, string name, uint256 date, uint256 priceUSD, uint256 capacity);
    event TicketPurchased(uint256 eventId, address buyer, uint256 amountPaid);

    // Membuat event baru
    function createEvent(
        string memory _name,
        uint256 _date,
        uint256 _priceUSD, // Harga tiket dalam USD (6 desimal)
        uint256 _capacity
    ) external onlyOwner {
        require(_date > block.timestamp, "Event date must be in the future");
        require(_capacity > 0, "Capacity must be greater than 0");

        events[nextEventId] = Event({
            name: _name,
            date: _date,
            priceUSD: _priceUSD,
            capacity: _capacity,
            ticketsSold: 0,
            isActive: true
        });

        emit EventCreated(nextEventId, _name, _date, _priceUSD, _capacity);
        nextEventId++;
    }

    // Membeli tiket
    function buyTicket(uint256 _eventId) external payable nonReentrant {
        Event storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event is not active");
        require(myEvent.ticketsSold < myEvent.capacity, "Tickets sold out");
        require(block.timestamp < myEvent.date, "Event already started");

        // Konversi harga USD ke ETH (1 ETH = 3000 USD)
        uint256 priceInWei = (myEvent.priceUSD * 1e18) / ETH_TO_USD_RATE;
        require(msg.value >= priceInWei, "Insufficient ETH sent");

        // Tambahkan peserta ke event
        myEvent.ticketsSold++;
        eventAttendees[_eventId].push(msg.sender);

        emit TicketPurchased(_eventId, msg.sender, msg.value);

        // Refund kelebihan jika ada
        uint256 excess = msg.value - priceInWei;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

    // Menarik dana hasil penjualan tiket
    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }

    // Mendapatkan peserta untuk event tertentu
    function getEventAttendees(uint256 _eventId) external view returns (address[] memory) {
        return eventAttendees[_eventId];
    }
}
