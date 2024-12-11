// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract TicketingSystem {
    address public owner;
    uint256 public creationFee = 0.00001 ether; // Fee untuk membuat tiket (sudah diubah agar lebih kecil)
    uint256 public purchaseFeePercent = 5;   // Fee pembelian (persen)

    // Nilai konversi USD ke ETH
    uint256 public usdToEthConversionRate = 3749; // 1 ETH = 3749 USD (static conversion rate)

    struct Ticket {
        uint256 id; // ID unik tiket
        string eventName;
        uint256 priceInETH; // Harga tiket dalam ETH
        uint256 available;
        address seller;
    }

    mapping(uint256 => Ticket) public tickets; // Tiket berdasarkan ID
    uint256 public nextTicketId; // Counter untuk ID tiket

    event TicketCreated(uint256 ticketId, string eventName, uint256 priceInETH, uint256 available, address seller);
    event TicketPurchased(uint256 ticketId, address buyer, uint256 quantity, uint256 fee);
    event TicketUpdated(uint256 ticketId, uint256 newPrice, uint256 newAvailable);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Seller membuat tiket baru
    function createTicket(string memory eventName, uint256 priceInUSD, uint256 available) public payable {
        require(msg.sender.balance >= creationFee, "Fee tidak mencukupi"); // Pastikan ada fee untuk pembuatan tiket
        require(priceInUSD > 0, "Harga harus lebih besar dari 0");
        require(available > 0, "Jumlah tiket harus lebih besar dari 0");

        // Konversi harga tiket dari USD ke ETH menggunakan nilai tukar statis
        uint256 priceInETH = priceInUSD * 1 ether / usdToEthConversionRate;

        // Buat tiket baru
        tickets[nextTicketId] = Ticket({
            id: nextTicketId,
            eventName: eventName,
            priceInETH: priceInETH, // Harga tiket dalam ETH
            available: available,
            seller: msg.sender
        });

        emit TicketCreated(nextTicketId, eventName, priceInETH, available, msg.sender);

        nextTicketId++;
    }

    // Buyer membeli tiket
    function buyTicket(uint256 ticketId, uint256 quantity) public payable {
        Ticket storage ticket = tickets[ticketId];
        require(ticket.available >= quantity, "Tiket tidak mencukupi");
        uint256 totalPrice = ticket.priceInETH * quantity;
        uint256 fee = (totalPrice * purchaseFeePercent) / 100;
        require(msg.value >= totalPrice + fee, "Ether tidak mencukupi");

        // Transfer dana ke seller dan fee ke owner
        payable(ticket.seller).transfer(totalPrice);
        payable(owner).transfer(fee); // Fee ke owner

        // Update stok tiket
        ticket.available -= quantity;

        emit TicketPurchased(ticketId, msg.sender, quantity, fee);
    }

    // Seller memperbarui tiket
    function updateTicket(uint256 ticketId, uint256 newPriceInUSD, uint256 newAvailable) public {
        Ticket storage ticket = tickets[ticketId];
        require(ticket.seller == msg.sender, "Hanya pembuat tiket yang dapat mengubah");
        require(newPriceInUSD > 0, "Harga harus valid");
        require(newAvailable >= ticket.available, "Jumlah tidak valid");

        // Konversi harga tiket dari USD ke ETH
        uint256 newPriceInETH = newPriceInUSD * 1 ether / usdToEthConversionRate;

        ticket.priceInETH = newPriceInETH;
        ticket.available = newAvailable;

        emit TicketUpdated(ticketId, newPriceInETH, newAvailable);
    }

    // Fungsi untuk melihat semua tiket
    function seeAllTickets() public view returns (Ticket[] memory) {
        Ticket[] memory allTickets = new Ticket[](nextTicketId);
        for (uint256 i = 0; i < nextTicketId; i++) {
            allTickets[i] = tickets[i];
        }
        return allTickets;
    }
}

