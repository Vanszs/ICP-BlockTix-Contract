// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Interface {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract MotokoShinkaizzzzzzz {
    uint256 public constant ETH_TO_USD_RATE = 3000; 
    uint256 public constant USD_DECIMALS = 6;
    uint256 public constant ADMIN_FEE_PERCENTAGE = 10;
    IERC20Interface public testToken;
    address public owner;
    uint256 public adminFeeETH;   
    uint256 public adminFeeTokens; 

    struct Event {
        string name;
        uint256 date;
        uint256 priceUSD;
        uint256 capacity;
        uint256 ticketsSold;
        bool isActive;
        address creator;
        uint256 balanceETH;
        uint256 balanceTokens;
        bool isCanceled; 
    }
    mapping(uint256 => mapping(address => uint256)) public userEthPaid;
    mapping(uint256 => mapping(address => uint256)) public userTokenPaid;

    mapping(uint256 => Event) public events;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public whitelistedCreators;
    mapping(address => bool) public coOwners;

    // Modifier baru untuk owner atau co-owner
    modifier onlyOwnerOrCoOwner() {
        require(msg.sender == owner || coOwners[msg.sender], "Only owner or co-owner can perform this action");
        _;
    }
    
    // Fungsi untuk menambahkan co-owner
    function addCoOwner(address _coOwner) external onlyOwner {
        require(_coOwner != address(0), "Invalid address");
        coOwners[_coOwner] = true;
    }
    
    // Fungsi untuk menghapus co-owner
    function removeCoOwner(address _coOwner) external onlyOwner {
        require(coOwners[_coOwner], "Address is not a co-owner");
        coOwners[_coOwner] = false;
    }

    uint256 public nextEventId;

    event EventCreated(uint256 eventId, string name, uint256 date, uint256 priceUSD, uint256 capacity, address creator);
    event EventUpdated(uint256 eventId, uint256 newDate, uint256 newPriceUSD, uint256 newCapacity);
    event TicketPurchased(uint256 eventId, address buyer, uint256 amountPaid, string paymentMethod);
    event AdminFeeWithdrawn(address admin, uint256 feeETH, uint256 feeTokens);
    event FundsWithdrawn(uint256 eventId, address recipient, uint256 balanceETH, uint256 balanceTokens);
    event BlacklistUpdated(address indexed user, bool isBlacklisted);
    event Whitelistadd(address);
    event EthReceived(address indexed sender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyCreator(uint256 _eventId) {
        require(events[_eventId].creator == msg.sender, "Only the creator can perform this action");
        _;
    }

    modifier notBlacklisted() {
        require(!blacklist[msg.sender], "Address is blacklisted");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelistedCreators[msg.sender], "Not whitelisted to create events");
        _;
    }

    constructor(address _tokenAddress) {
        owner = msg.sender;
        testToken = IERC20Interface(_tokenAddress);
    }

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    function createEvent(
        string memory _name,
        uint256 _date,
        uint256 _priceUSD,
        uint256 _capacity
    ) external onlyWhitelisted {
        require(_date > block.timestamp, "Event date must be in the future");
        require(_capacity > 0, "Capacity must be greater than 0");
        events[nextEventId] = Event({
            name: _name,
            date: _date,
            priceUSD: _priceUSD, 
            capacity: _capacity,
            ticketsSold: 0,
            isActive: true,
            creator: msg.sender,
            balanceETH: 0,
            balanceTokens: 0,
            isCanceled: false // default false
        });

        emit EventCreated(nextEventId, _name, _date, _priceUSD, _capacity, msg.sender);
        nextEventId++;
    }

    // function buyTicketWithETH(uint256 _eventId) external payable notBlacklisted {
    //     Event storage myEvent = events[_eventId];
    //     require(myEvent.isActive, "Event is not active");
    //     require(!myEvent.isCanceled, "Event is canceled");
    //     require(myEvent.ticketsSold < myEvent.capacity, "Tickets sold out");
    //     require(block.timestamp < myEvent.date, "Event already started");

    //     uint256 priceInWei = (myEvent.priceUSD * 1e18) / ETH_TO_USD_RATE;
    //     uint256 adminFee = (priceInWei * ADMIN_FEE_PERCENTAGE) / 100;
    //     uint256 netToEvent = priceInWei - adminFee;

    //     require(msg.value >= priceInWei, "Insufficient ETH sent");

    //     myEvent.ticketsSold++;
    //     myEvent.balanceETH += netToEvent; 
    //     adminFeeETH += adminFee; 

    //     userEthPaid[_eventId][msg.sender] += netToEvent;

    //     emit TicketPurchased(_eventId, msg.sender, msg.value, "ETH");
    // }
        function buyTicketWithETH(uint256 _eventId) external payable {
        Event storage e = events[_eventId];
        require(e.isActive, "Event not active.");
        require(!e.isCanceled, "Event is canceled.");
        require(e.ticketsSold < e.capacity, "Tickets sold out.");
        require(block.timestamp < e.date, "Event already started/ended.");

        // Pastikan ETH yang dikirim cukup
        uint256 requiredETH = 0;
        require(msg.value >= requiredETH, "Insufficient ETH sent.");

        // Hitung fee admin
        uint256 fee = (requiredETH * ADMIN_FEE_PERCENTAGE) / 100;
        uint256 netToEvent = requiredETH - fee;

        // Update data penjualan
        // e.sold++;
        e.balanceETH += netToEvent;
        adminFeeETH += fee;
        userEthPaid[_eventId][msg.sender] += requiredETH; // Catat untuk keperluan refund
        emit TicketPurchased(_eventId, msg.sender, "ETH", requiredETH);
    }

    function buyTicketWithToken(uint256 _eventId) external notBlacklisted {
        Event storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event is not active");
        require(!myEvent.isCanceled, "Event is canceled");
        require(myEvent.ticketsSold < myEvent.capacity, "Tickets sold out");
        require(block.timestamp < myEvent.date, "Event already started");

        uint256 priceInTokens = myEvent.priceUSD * (10**USD_DECIMALS);
        uint256 adminFee = (priceInTokens * ADMIN_FEE_PERCENTAGE) / 100;
        uint256 netToEvent = priceInTokens - adminFee;

        uint256 totalRequired = priceInTokens; 
        uint256 allowance = testToken.allowance(msg.sender, address(this));

        require(allowance >= totalRequired, "Token allowance too low");

        // Transfer totalRequired ke kontrak
        // netToEvent buat event, adminFee buat global admin
        testToken.transferFrom(msg.sender, address(this), totalRequired);
        
        myEvent.ticketsSold++;
        myEvent.balanceTokens += netToEvent; 
        adminFeeTokens += adminFee;

        // Simpan total akumulasi Token yang pernah dibayarkan user ini untuk event ini
        userTokenPaid[_eventId][msg.sender] += netToEvent;

        emit TicketPurchased(_eventId, msg.sender, totalRequired, "TOKEN");
    }

    function withdrawEventFunds(uint256 _eventId) external onlyCreator(_eventId) {
        Event storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event already withdrawn or not active");
        require(!myEvent.isCanceled, "Event is canceled, cannot withdraw. Please refund users.");
        require(block.timestamp >= myEvent.date, "Event not yet ended");

        uint256 balanceETH = myEvent.balanceETH;
        uint256 balanceTokens = myEvent.balanceTokens;

        require(balanceETH > 0 || balanceTokens > 0, "No funds to withdraw");

        if (balanceETH > 0) {
            payable(msg.sender).transfer(balanceETH);
        }

        if (balanceTokens > 0) {
            require(testToken.transfer(msg.sender, balanceTokens), "Token transfer failed");
        }

        myEvent.balanceETH = 0;
        myEvent.balanceTokens = 0;
        myEvent.isActive = false;

        emit FundsWithdrawn(_eventId, msg.sender, balanceETH, balanceTokens);
    }

    function withdrawAdminFee() external onlyOwner {
        uint256 feeETH = adminFeeETH;
        uint256 feeTokens = adminFeeTokens;

        if (feeETH > 0) {
            payable(owner).transfer(feeETH);
        }
        if (feeTokens > 0) {
            require(testToken.transfer(owner, feeTokens), "Token transfer failed");
        }

        adminFeeETH = 0;
        adminFeeTokens = 0;

        emit AdminFeeWithdrawn(owner, feeETH, feeTokens);
    }

    function editEvent(
        uint256 _eventId,
        uint256 _newDate,
        uint256 _newPriceUSD,
        uint256 _newCapacity
    ) external onlyCreator(_eventId) {
        Event storage myEvent = events[_eventId];
        require(_newDate > block.timestamp, "New date must be in the future");
        require(!myEvent.isCanceled, "Event is canceled");
        require(_newCapacity >= myEvent.ticketsSold, "New capacity must be >= tickets sold");

        myEvent.date = _newDate;
        myEvent.priceUSD = _newPriceUSD;
        myEvent.capacity = _newCapacity;

        emit EventUpdated(_eventId, _newDate, _newPriceUSD, _newCapacity);
    }

    function updateBlacklist(address _user, bool _isBlacklisted) external onlyOwnerOrCoOwner {
        require(_user != address(0), "Invalid address");
        require(blacklist[_user] != _isBlacklisted, "No changes in blacklist status");
        blacklist[_user] = _isBlacklisted;

        if (_isBlacklisted) {
            whitelistedCreators[_user] = false;
        }

        emit BlacklistUpdated(_user, _isBlacklisted);
    }

    function addWhitelistedCreator(address _creator) external onlyOwnerOrCoOwner {
        require(_creator != address(0), "Invalid address");
        require(!whitelistedCreators[_creator], "Address already whitelisted");

        blacklist[_creator] = false;
        whitelistedCreators[_creator] = true;

        emit Whitelistadd(_creator);
    }

    function getAllEvents() external view returns (Event[] memory) {
        Event[] memory allEvents = new Event[](nextEventId);
        for (uint256 i = 0; i < nextEventId; i++) {
            allEvents[i] = events[i];
        }
        return allEvents;
    }

    function getUserStatus(address wallet) external view returns (string memory) {
        if (whitelistedCreators[wallet]) {
            return "Whitelisted";
        } else if (blacklist[wallet]) {
            return "Blacklisted";
        } else {
            return "Unlisted";
        }
    }

    function TestwithdrawAllFunds() external onlyOwnerOrCoOwner {
        uint256 contractBalance = address(this).balance; 
        require(contractBalance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Transfer failed");
    }


    /**
     * @notice Hanya creator event yang boleh membatalkan event
     */
    function cancelEvent(uint256 _eventId) external onlyCreator(_eventId) {
        Event storage myEvent = events[_eventId];
        require(!myEvent.isCanceled, "Event already canceled");
        myEvent.isCanceled = true;
    }

    /**
     * @notice Refund bagi user jika event dibatalkan dan user punya tiket yang belum di-refund
     */
    function refund(uint256 _eventId) external notBlacklisted {
        Event storage myEvent = events[_eventId];
        require(myEvent.isCanceled, "Event is not canceled");

        uint256 ethAmount = userEthPaid[_eventId][msg.sender];
        uint256 tokenAmount = userTokenPaid[_eventId][msg.sender];

        require(ethAmount > 0 || tokenAmount > 0, "No tickets purchased or already refunded");

        if (ethAmount > 0) {
            require(myEvent.balanceETH >= ethAmount, "Not enough ETH in event balance for refund");
            myEvent.balanceETH -= ethAmount;
            userEthPaid[_eventId][msg.sender] = 0; // tandai sudah refund
            payable(msg.sender).transfer(ethAmount);
        }

        if (tokenAmount > 0) {
            require(myEvent.balanceTokens >= tokenAmount, "Not enough tokens in event balance for refund");
            myEvent.balanceTokens -= tokenAmount;
            userTokenPaid[_eventId][msg.sender] = 0; // tandai sudah refund
            require(testToken.transfer(msg.sender, tokenAmount), "Token transfer failed");
        }
    }

    function CheckProfit() public view returns (uint256, uint256) {
        return (adminFeeETH, adminFeeTokens);
    }

}
