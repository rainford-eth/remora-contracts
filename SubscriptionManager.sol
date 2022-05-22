// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.7.0;


import "../../math/SafeMath.sol";
import "../../utils/Address.sol";
import "../../token/ERC20/IERC20.sol";


contract SubscriptionManager {
    using SafeMath for uint256;
    using Address for address;

    address private _owner;
    uint256 private _max = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private _intervalLimit;
    uint256 private _amountLimit;
    mapping (address => Merchant) private _merchants;

    // events
    event Create(address indexed _merchant, address indexed _subscriber, uint256 indexed _amount, uint256 indexed _interval, address indexed _token);
    event Modify(address indexed _merchant, address indexed _subscriber, uint256 indexed _amount, uint256 indexed _interval, address indexed _token);
    event Cancel(address indexed _merchant, address indexed _subscriber);
    event Charge(address indexed _merchant, address indexed _subscriber, uint256 indexed _amount);
    event ChangeLimits(address indexed _changer, uint256 indexed _amount, uint256 indexed _interval);
    event ChangeOwner(address indexed _oldOwner, address indexed _newOwner);

    // struct for subscription info
    struct Subscription {
        uint256 amount; // amount to charge each interval
        uint256 interval; // interval time
        uint256 tokenAddress; // contract address of the token being paid.
        uint256 lastCharge; // last subscription perdiod start date
    }

    // struct for accessing merchant info, including subscriber list
    struct Merchant {
        mapping (address => Subscription) subscriptions; // mapping subscriber addresses to subscription data
    }

    constructor() {
        _owner = msg.sender;
        _intervalLimit = 86400;
        _amountLimit = 100000000000;
    }

    // check if this contract is approved to spend an ERC20 token for a given subscriber
    function _checkApproval(address tokenAddr, address subAddr) internal returns (bool) {
        if (IERC20(tokenAddr).allowance(subAddr, address(this)) > 1000000) {
            return true;
        } else {
            return false;
        }
    }

    // create subscription
    function createSubscription(uint256 amount, uint256 interval, address merchantAddr, address tokenAddr) {
        require(_checkApproval(tokenAddr, msg.sender), "User needs to approve() token first.");
        // make sure not already subscribed
        require(_merchants[merchantAddr].subscriptions[msg.sender].amount == 0, "User already subscribed.");
        require(amount % 100 == 0, "Payment amount must be divisible by 100 gwei.");
        require(interval >= _intervalLimit, "Interval too low.");
        require(amount <= amountLimit, "Amount too high.");

        _merchants[merchantAddr].subscriptions[msg.sender] = Subscription(amount, interval, tokenAddr, block.timestamp);

        emit Create(merchantAddr, msg.sender, amount, interval, tokenAddr);
    }

    // cancel subscription (internal)
    function _cancel(address merchantAddr, address subAddr) private {
        _merchants[merchantAddr].subscriptions[subAddr].amount = 0;
        emit Cancel(merchantAddr, subAddr);
    }

    // cancel subscription (for merchants)
    function cancelMerchant(address subscriberAddress) external {
        _cancel(msg.sender, subscriberAddress);
    }

    // cancel subscription (for subscribers)
    function cancelSubscriber(address merchantAddress) external {
        _cancel(merchantAddress, msg.sender);
    }

    // charge a particular address
    function charge(address merchantAddr, address subscriberAddr) public {
        // ensure payment is at least 100 wei DKHGSESKAUGNAKSGNFAKSJ SO THOD DO THIS
        require(_merchants[merchantAddr].subscriptions[subscriberAddr].amount > 0, "Subscription does not exist");
        require(block.timestamp - _merchants[merchantAddr].subscriptions[subscriberAddr].lastCharge > _merchants[merchantAddr].subscriptions[subscriberAddr].interval, "Payment already made for the current period.");

        // transfer main payment
        IERC20(_merchants[merchantAddr].subscriptions[subscriberAddr].tokenAddress).transferFrom(subscriberAddr, merchantAddr, _merchants[merchantAddr].subscriptions[subscriberAddr].amount * 99 / 100);
        // transfer commission payment
        IERC20(_merchants[merchantAddr].subscriptions[subscriberAddr].tokenAddress).transferFrom(subscriberAddr, _owner, _merchants[merchantAddr].subscriptions[subscriberAddr].amount / 100);

        _merchants[merchantAddr].subscriptions[subscriberAddr].lastCharge += _merchants[merchantAddr].subscriptions[subscriberAddr].interval;

        emit Charge(merchantAddr, subscriberAddr, _merchants[merchantAddr].subscriptions[subscriberAddr].amount);
    }

    // modify subscription
    function modifySubscription(address merchantAddr, uint256 amount, uint256 interval, uint256 tokenAddr) {
        require(_merchants[merchantAddr].subscriptions[subscriberAddr].amount > 0, "Subscription does not exist");
        require(amount % 100 == 0, "Payment amount must be divisible by 100 gwei.");
        require(interval >= _intervalLimit, "Interval too low.");
        require(amount <= amountLimit, "Amount too high.");

        _merchants[merchantAddr].subscriptions[msg.sender] = Subscription(amount, interval, tokenAddr, block.timestamp);

        emit Modify(merchantAddr, msg.sender, amount, interval, tokenAddr);
    }


    // set interval/amount limits -- but only lower/raise them, can't go back, emit event
    function raiseLimits(amount, interval) {
        require(msg.sender == _owner, "You must be the owner of this contract to modify limits.");
        // you can only expand the limits, not limit further.
        require(amount > _amountLimit, "You can only expand the limits.");
        require(interval < _intervalLimit, "You can only expand the limits.");

        _amountLimit = amount;
        _intervalLimit = interval;
        emit ChangeLimits(msg.sender, amount, interval);
    }

    // read owner address
    function readOwner() public view returns (address) {
        return _owner;
    }

    // change owner
    function changeOwner(address newOwner) {
        require(msg.sender == _owner, "You are not the owner of this contract");
        emit ChangeOwner(_owner, newOwner);
        _owner = newOwner;
    }

    // check a subscription's values
    function readSubscription(address merchantAddress, address subscriberAddress) public view returns (Subscription) {
        return _merchants[merchantAddress].subscriptions[subscriberAddress];
    }
}