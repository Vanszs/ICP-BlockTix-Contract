// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MotokoShinkai {
    uint256 public constant ETH_TO_USD_RATE = 3000; // 1 ETH = $3000
    uint256 public constant USD_DECIMALS = 6;

    IERC20 public testToken;

    struct Event {
        string name;
        uint256 date;
        uint256 priceUSD;
        uint256 capacity;
        uint256 ticketsSold;
        bool isActive;
    }

    mapping(uint256 => Event) public events;
    mapping(uint256 => address[]) public eventAttendees;
    uint256 public nextEventId;

    event EventCreated(uint256 eventId, string name, uint256 date, uint256 priceUSD, uint256 capacity);
    event TicketPurchased(uint256 eventId, address buyer, uint256 amountPaid, string paymentMethod);
    event FundsWithdrawn(uint256 eventId, address recipient);
    

    constructor(address _tokenAddress) {
        testToken = IERC20(_tokenAddress);
    }

function createEvent(
    string memory _name,
    uint256 _date,
    uint256 _priceUSD,
    uint256 _capacity
) external {
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


    function buyTicketWithETH(uint256 _eventId) external payable {
        Event storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event is not active");
        require(myEvent.ticketsSold < myEvent.capacity, "Tickets sold out");
        require(block.timestamp < myEvent.date, "Event already started");

        uint256 priceInWei = (myEvent.priceUSD * 1e18) / ETH_TO_USD_RATE;
        require(msg.value >= priceInWei, "Insufficient ETH sent");

        myEvent.ticketsSold++;
        eventAttendees[_eventId].push(msg.sender);

        emit TicketPurchased(_eventId, msg.sender, msg.value, "ETH");

        uint256 excess = msg.value - priceInWei;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }

    function buyTicketWithToken(uint256 _eventId) external {
        Event storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event is not active");
        require(myEvent.ticketsSold < myEvent.capacity, "Tickets sold out");
        require(block.timestamp < myEvent.date, "Event already started");

        uint256 priceInTokens = myEvent.priceUSD * (10 ** USD_DECIMALS);
        require(testToken.allowance(msg.sender, address(this)) >= priceInTokens, "Token allowance too low");

        testToken.transferFrom(msg.sender, address(this), priceInTokens);

        myEvent.ticketsSold++;
        eventAttendees[_eventId].push(msg.sender);

        emit TicketPurchased(_eventId, msg.sender, priceInTokens, "TOKEN");
    }

    function withdrawFunds(uint256 _eventId) external {
        Event storage myEvent = events[_eventId];
        require(block.timestamp >= events[_eventId].date, "Event not yet ended");
        require(myEvent.isActive, "Event already withdrawn");
        myEvent.isActive = false;

        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(balance);

        emit FundsWithdrawn(_eventId, msg.sender);
    }
    function getEventAttendees(uint256 _eventId) external view returns (address[] memory) {
    return eventAttendees[_eventId];
}

}
