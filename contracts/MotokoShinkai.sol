// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MotokoShinkai {
    // ----------------------------------------------------------------
    // STORAGE: ADMIN, BLACKLIST, WHITELIST, CO-OWNERS
    // ----------------------------------------------------------------
    address public owner;

    // Admin & co-owner
    mapping(address => bool) public coOwners;

    // Sistem blacklist & whitelist
    mapping(address => bool) public blacklist;
    mapping(address => bool) public whitelistedCreators;

    // Fee admin
    uint256 public constant ADMIN_FEE_PERCENTAGE = 10; 
    uint256 public adminFeeETH;   

    // ----------------------------------------------------------------
    // EVENT STRUCT & STORAGE
    // ----------------------------------------------------------------
    struct EventInfo {
        string name;          
        uint256 date;         
        uint256 priceETHWei;  
        uint256 capacity;     
        uint256 sold;         
        bool isActive;        
        bool isCanceled;      
        address creator;      
        uint256 balanceETH;   
    }

    uint256 public nextEventId;
    mapping(uint256 => EventInfo) public events;

    // Untuk mencatat berapa ETH yang pernah user bayarkan ke suatu event, guna keperluan refund
    mapping(uint256 => mapping(address => uint256)) public userEthPaid;
    mapping(uint256 => mapping(address => uint256)) public ticketsBought;


    // ----------------------------------------------------------------
    // EVENTS (LOG)
    // ----------------------------------------------------------------
    event EthReceived(address indexed sender, uint256 amount);
    event EventCreated(uint256 eventId, string name, uint256 date, uint256 priceETHWei, uint256 capacity, address creator);
    event TicketPurchased(uint256 eventId, address buyer, uint256 amountPaid);
    event FundsWithdrawn(uint256 eventId, address recipient, uint256 balanceETH);
    event AdminFeeWithdrawn(address admin, uint256 feeETH);
    event EventCanceled(uint256 eventId);
    event BlacklistUpdated(address indexed user, bool isBlacklisted);
    event Whitelistadd(address indexed creator);

    // ----------------------------------------------------------------
    // MODIFIERS
    // ----------------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyOwnerOrCoOwner() {
        require(msg.sender == owner || coOwners[msg.sender], "Only owner or co-owner can perform this action");
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

    // ----------------------------------------------------------------
    // CONSTRUCTOR & RECEIVE/FALLBACK
    // ----------------------------------------------------------------
    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    // ----------------------------------------------------------------
    // CO-OWNER MANAGEMENT
    // ----------------------------------------------------------------
    function addCoOwner(address _coOwner) external onlyOwner {
        require(_coOwner != address(0), "Invalid address");
        coOwners[_coOwner] = true;
    }

    function removeCoOwner(address _coOwner) external onlyOwner {
        require(coOwners[_coOwner], "Address is not a co-owner");
        coOwners[_coOwner] = false;
    }

    // ----------------------------------------------------------------
    // BLACKLIST & WHITELIST MANAGEMENT
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // CREATE & EDIT EVENT
    // ----------------------------------------------------------------
    function createEvent(
        string memory _name,
        uint256 _date,
        uint256 _priceETHWei,
        uint256 _capacity
    ) external onlyWhitelisted {
        require(_date > block.timestamp, "Event date must be in the future");
        require(_capacity > 0, "Capacity must be greater than 0");

        events[nextEventId] = EventInfo({
            name: _name,
            date: _date,
            priceETHWei: _priceETHWei,
            capacity: _capacity,
            sold: 0,
            isActive: true,
            isCanceled: false,
            creator: msg.sender,
            balanceETH: 0
        });

        emit EventCreated(
            nextEventId,
            _name,
            _date,
            _priceETHWei,
            _capacity,
            msg.sender
        );

        nextEventId++;
    }

    function editEvent(
        uint256 _eventId,
        uint256 _newDate,
        uint256 _newPriceETHWei,
        uint256 _newCapacity
    ) external onlyCreator(_eventId) {
        EventInfo storage myEvent = events[_eventId];
        require(_newDate > block.timestamp, "New date must be in the future");
        require(!myEvent.isCanceled, "Event is canceled");
        require(_newCapacity >= myEvent.sold, "New capacity must be >= tickets sold");

        myEvent.date = _newDate;
        myEvent.priceETHWei = _newPriceETHWei;
        myEvent.capacity = _newCapacity;
    }

    // ----------------------------------------------------------------
    // BUY TICKET: ETH
    // ----------------------------------------------------------------
function buyTicketWithETH(uint256 _eventId, uint256 ticketCount) external payable notBlacklisted {
    EventInfo storage myEvent = events[_eventId];
    require(myEvent.isActive, "Event is not active");
    require(!myEvent.isCanceled, "Event is canceled");
    require(myEvent.sold + ticketCount <= myEvent.capacity, "Not enough tickets available");
    require(block.timestamp < myEvent.date, "Event already started or ended");
    require(ticketCount > 0, "Ticket count must be greater than 0");

    uint256 totalPriceInWei = myEvent.priceETHWei * ticketCount; 
    require(msg.value >= totalPriceInWei, "Insufficient ETH sent");

    // Hitung admin fee untuk semua tiket
    uint256 adminFee = (totalPriceInWei * ADMIN_FEE_PERCENTAGE) / 100;
    uint256 netToEvent = totalPriceInWei - adminFee;

    // Update penjualan
    myEvent.sold += ticketCount;
    myEvent.balanceETH += netToEvent; 
    adminFeeETH += adminFee; 

    // Simpan total ETH user yang dibayar (untuk refund)
    userEthPaid[_eventId][msg.sender] += totalPriceInWei;

    // Refund jika ada kelebihan pembayaran
    if (msg.value > totalPriceInWei) {
        payable(msg.sender).transfer(msg.value - totalPriceInWei);
    }

    emit TicketPurchased(_eventId, msg.sender, totalPriceInWei);
}


    // ----------------------------------------------------------------
    // WITHDRAW EVENT FUNDS (CREATOR)
    // ----------------------------------------------------------------
    function withdrawEventFunds(uint256 _eventId) external onlyCreator(_eventId) {
        EventInfo storage myEvent = events[_eventId];
        require(myEvent.isActive, "Event not active or already withdrawn");
        require(!myEvent.isCanceled, "Event canceled, must refund users");
        require(block.timestamp >= myEvent.date, "Event not yet ended");

        uint256 balanceETH = myEvent.balanceETH;
        require(balanceETH > 0, "No funds to withdraw");

        payable(msg.sender).transfer(balanceETH);
        myEvent.balanceETH = 0;
        myEvent.isActive = false;

        emit FundsWithdrawn(_eventId, msg.sender, balanceETH);
    }

    // ----------------------------------------------------------------
    // WITHDRAW ADMIN FEE (OWNER)
    // ----------------------------------------------------------------
    function withdrawAdminFee() external onlyOwnerOrCoOwner() {
        uint256 feeETH = adminFeeETH;

        if (feeETH > 0) {
            payable(owner).transfer(feeETH);
            adminFeeETH = 0;
        }

        emit AdminFeeWithdrawn(owner, feeETH);
    }

       // ----------------------------------------------------------------
    // CANCEL EVENT (CREATOR) & REFUND
    // ----------------------------------------------------------------
    function cancelEvent(uint256 _eventId) external onlyCreator(_eventId) {
        EventInfo storage myEvent = events[_eventId];
        require(!myEvent.isCanceled, "Event already canceled");
        myEvent.isCanceled = true;

        emit EventCanceled(_eventId);
    }

    function refund(uint256 _eventId) external notBlacklisted {
        EventInfo storage myEvent = events[_eventId];
        require(myEvent.isCanceled, "Event not canceled");

        uint256 ethAmount = userEthPaid[_eventId][msg.sender];

        require(ethAmount > 0 , "No tickets purchased or already refunded");

        // Refund ETH
        if (ethAmount > 0) {
            require(myEvent.balanceETH >= ethAmount, "Not enough ETH in event balance");
            myEvent.balanceETH -= ethAmount;
            userEthPaid[_eventId][msg.sender] = 0;
            payable(msg.sender).transfer(ethAmount);
        }

    }

    // ----------------------------------------------------------------
    // EXTRA: CO-OWNER FORCE WITHDRAW & VIEW FUNCTIONS
    // ----------------------------------------------------------------
    /**
     * Contoh function untuk co-owner/owner menarik SELURUH ETH di kontrak
     * (misal untuk emergensi). Pastikan paham risikonya.
     */
    function TestwithdrawAllFunds() external onlyOwnerOrCoOwner {
        uint256 contractBalance = address(this).balance; 
        require(contractBalance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner).call{value: contractBalance}("");
        require(success, "Transfer failed");
    }

    function getAllEvents() external view returns (EventInfo[] memory) {
        EventInfo[] memory allEvents = new EventInfo[](nextEventId);
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

    function CheckProfit() public view returns (uint256) {
        return (adminFeeETH);
    }
}