//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract Registration is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public usdc;

    uint256 public usdcTotal;

    uint256 public totalAttendees;

    address payable public deposits;

    struct Event {
        uint256 id;
        string name;
        uint256 attendees;
    }

    mapping(uint256 => Event) public events;
    mapping(address => uint256) public eventAttending;
    mapping(address => bool) public depositMade;
    mapping(address => uint256) public amountDeposited;
    mapping(address => bool) public hasAttended;
    mapping(address => bool) public hasCollected;

    using Counters for Counters.Counter;
    Counters.Counter private _eventIds;

    event NewEventCreated(uint256 id, string name);
    event DepositComplete(
        address indexed attendee,
        uint256 eventId,
        uint256 amount
    );
    event DepositCollected(
        address indexed attendee,
        uint256 eventId,
        uint256 amount
    );

    constructor(IERC20 _usdc, address payable _deposits) {
        usdc = _usdc;
        deposits = _deposits;
        _eventIds.increment();
    }

    function createEvent(string memory name) public {
        uint256 newEventId = _eventIds.current();

        events[newEventId] = Event({id: newEventId, name: name, attendees: 0});

        _eventIds.increment();

        emit NewEventCreated(newEventId, name);
    }

    function contribute(uint256 eventId) external payable {
        _contribute(eventId);
    }

    function _contribute(uint256 eventId) internal nonReentrant {
        require(msg.value > 0, "No amount sent");

        amountDeposited[msg.sender] = amountDeposited[msg.sender].add(
            msg.value
        );
        usdcTotal = usdcTotal.add(msg.value);

        depositMade[msg.sender] = true;
        eventAttending[msg.sender] = eventId;

        emit DepositComplete(msg.sender, eventId, msg.value);
    }

    function collect(uint256 eventId) external nonReentrant {
        require(
            hasAttended[msg.sender] == true,
            "You did not attend. Deposit is forfeit."
        );
        require(
            hasCollected[msg.sender] == false,
            "Address already collected."
        );
        require(
            amountDeposited[msg.sender] > 0,
            "Address did not make a deposite."
        );

        hasCollected[msg.sender] = true;
        uint256 contribution = amountDeposited[msg.sender].mul(1e12).div(
            usdcTotal
        );
        _safeUsdcTransfer(msg.sender, contribution);

        emit DepositCollected(msg.sender, eventId, contribution);
    }

    function recordAttendance(address attendee) external onlyOwner {
        hasAttended[attendee] = true;
    }

    function getEventAttending(address attendee) public view returns (uint256) {
        return eventAttending[attendee];
    }

    function getAmountDeposited(address attendee)
        public
        view
        returns (uint256)
    {
        return amountDeposited[attendee];
    }

    function withdraw() external onlyOwner {
        deposits.transfer(usdc.balanceOf(address(this)));
    }

    function _safeUsdcTransfer(address _to, uint256 _amount) internal {
        uint256 usdcBal = usdc.balanceOf(address(this));
        if (_amount > usdcBal) {
            usdc.safeTransfer(_to, usdcBal);
        } else {
            usdc.safeTransfer(_to, _amount);
        }
    }
}
