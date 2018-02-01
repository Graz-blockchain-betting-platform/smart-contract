pragma solidity ^0.4.18;

library SafeMath {

    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

}

contract ERC20Basic {
    uint256 public totalSupply;

    function balanceOf(address who) constant public returns (uint256);

    function transfer(address to, uint256 value) public returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant public returns (uint256);

    function transferFrom(address from, address to, uint256 value) public returns (bool);

    function approve(address spender, uint256 value) public returns (bool);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Owned {

    address public owner;

    address public newOwner;

    function Owned() public payable {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(owner == msg.sender);
        _;
    }

    function changeOwner(address _owner) onlyOwner public {
        require(_owner != 0);
        newOwner = _owner;
    }

    function confirmOwner() public {
        require(newOwner == msg.sender);
        owner = newOwner;
        delete newOwner;
    }
}

contract Blocked {

    uint public blockedUntil;

    modifier unblocked {
        require(now > blockedUntil);
        _;
    }
}

contract BasicToken is ERC20Basic, Blocked {

    using SafeMath for uint256;

    mapping (address => uint256) balances;

    // Fix for the ERC20 short address attack
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) unblocked public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant public returns (uint256 balance) {
        return balances[_owner];
    }

}

contract StandardToken is ERC20, BasicToken {

    mapping (address => mapping (address => uint256)) allowed;

    function transferFrom(address _from, address _to, uint256 _value) onlyPayloadSize(3 * 32) unblocked public returns (bool) {
        var _allowance = allowed[_from][msg.sender];

        balances[_to] = balances[_to].add(_value);
        balances[_from] = balances[_from].sub(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) onlyPayloadSize(2 * 32) unblocked public returns (bool) {

        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) onlyPayloadSize(2 * 32) unblocked constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}

contract GrazCoin is StandardToken, Owned {

    string public constant name = "Graz Coin";

    string public constant symbol = "GRZ";

    uint32 public constant decimals = 18;

    function manualTransfer(address _to, uint256 _value) internal returns (bool) {
        balances[this] = balances[this].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(this, _to, _value);
        return true;
    }
}

contract ManualSendingCrowdsale is GrazCoin {
    using SafeMath for uint256;

    struct AmountData {
        bool exists;
        uint256 value;
    }

    mapping (uint => AmountData) public amountsByCurrency;

    function addCurrency(uint currency) external onlyOwner {
        addCurrencyInternal(currency);
    }

    function addCurrencyInternal(uint currency) internal {
        AmountData storage amountData = amountsByCurrency[currency];
        amountData.exists = true;
    }

    function manualTransferTokensToInternal(address to, uint256 givenTokens, uint currency, uint256 amount) internal returns (uint256) {
        AmountData memory tempAmountData = amountsByCurrency[currency];
        require(tempAmountData.exists);
        AmountData storage amountData = amountsByCurrency[currency];
        amountData.value = amountData.value.add(amount);
        return transferTokensTo(to, givenTokens);
    }

    function transferTokensTo(address to, uint256 givenTokens) internal returns (uint256);
}

contract CommonPhase is ManualSendingCrowdsale {

    uint256 public soldTokens = 0;

    function currentTime() internal view returns(uint) {
        return now;
    }
}

contract PreSalePhase is CommonPhase {

    // Date of start pre-ICO and ICO.
    uint public constant preSaleStartTime = 1517839200; // start at Monday, February 5, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint public constant preSaleEndTime =    preSaleStartTime + 14 days; // end at Tuesday, February 20, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint256 internal constant preSaleSoftCap = 50e21; // 50 thousands of tokens - it's a softcap.
    uint256 internal constant preSaleLimit = 300e21; // 300 thousands of tokens
    uint256 internal constant preSaleMinAmount = 4 ether;

    mapping (address => AmountData) public buyersAddresses;

    function PreSalePhase() public {
        addAddress(msg.sender);
    }

    function isPreSalePhase() public view returns (bool) {
        var curTime = currentTime();
        return curTime < preSaleEndTime && curTime >= preSaleStartTime;
    }

    function countPreSaleBonus(uint256 amountEther) internal view returns (uint) {
        if (!isPreSalePhase()) { return 0; }
        if (amountEther > 200 ether) { return 110; }
        if (amountEther > 100 ether) { return 105; }
        if (amountEther > 50 ether) { return 95; }
        if (amountEther > 20 ether) { return 85; }
        return 80;
    }

    function addAddress(address buyer) public onlyOwner {
        AmountData storage amountData = buyersAddresses[buyer];
        amountData.exists = true;
    }

    function canBuyOnPreSale(uint256 amountEther) internal view returns (bool) {
        AmountData memory tempAmountData = buyersAddresses[msg.sender];
        return (isPreSalePhase() && tempAmountData.exists && (amountEther > preSaleMinAmount || (msg.sender == owner)));
    }

    function refundPreSale() external {
        require(currentTime() > preSaleEndTime && soldTokens < preSaleSoftCap);
        AmountData memory tempAmountData = buyersAddresses[msg.sender];
        require(tempAmountData.exists);
        AmountData storage amountData = buyersAddresses[msg.sender];
        uint256 amount = amountData.value;
        require(amount > 0);
        amountData.value = 0;
        amountData.exists = false;
        require(msg.sender.call.gas(3000000).value(amount)());
        balances[msg.sender] = 0;
    }
}

contract PreICOPhase is PreSalePhase {

    // Date of start pre-ICO and ICO.
    // Start of preICO can be changed
    uint public preICOStartTime = 1521468000; // start at Monday, March 19, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint public preICOEndTime =   preICOStartTime + 22 days; // end at Friday March 23, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint256 internal constant preICOLimit = 3e24; // 3 mln of tokens

    function isPreICOPhase() public view returns (bool) {
        var curTime = currentTime();
        return curTime < preICOEndTime && curTime >= preICOStartTime;
    }

    function movePreICOTo(uint newTime) external onlyOwner {
        var curTime = currentTime();
        require(curTime < preICOStartTime && curTime < newTime);
        preICOStartTime = newTime;
        preICOEndTime =   preICOStartTime + 22 days;
    }

    function preICOTimeBonus() internal view returns (uint) {
       var curTime = currentTime();
       if (curTime <= preICOStartTime + 7 days) { return 40; }
       return 30;
    }

    function countPreICOBonus(uint256 amountEther) internal view returns (uint) {
        if (!isPreICOPhase()) { return 0; }
        uint bonus = preICOTimeBonus();
        if (amountEther > 200 ether) { return bonus + 30; }
        if (amountEther > 100 ether) { return bonus + 25; }
        if (amountEther > 50 ether) { return bonus + 15; }
        if (amountEther > 20 ether) { return bonus + 5; }
        return bonus;
    }
}

contract ICOPhase is PreICOPhase {

    // Date of start pre-ICO and ICO.
    uint public constant ICOStartTime = 1525183200; // start at Tuesday May 01, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint public constant ICOEndTime =    ICOStartTime + 31; // end at Friday June 01, 2018 14:00:00 (pm) in time zone UTC (UTC)
    uint256 internal constant ICOSoftCap = 7e24; // 7 mln of tokens - it's a softcap.
    uint256 internal constant ICOLimit = 85e24; // 82 mln of tokens
    mapping(address => uint256) ICOInvestors;

    function isICOPhase() public view returns (bool) {
        var curTime = currentTime();
        return curTime < ICOEndTime && curTime >= ICOStartTime;
    }

    function ICOTimeBonus() internal view returns (uint) {
       var curTime = currentTime();
       if (curTime <= preICOStartTime + 10 days) {
           return 20;
       }
       if (curTime <= preICOStartTime + 21 days) {
           return 15;
       }
       return 10;
    }

    function countICOBonus(uint256 amountEther) internal view returns (uint) {
        if (!isICOPhase()) { return 0; }
        uint bonus = ICOTimeBonus();
        if (amountEther > 1000 ether) { return bonus + 30; }
        if (amountEther > 500 ether) { return bonus + 25; }
        if (amountEther > 300 ether) { return bonus + 15; }
        if (amountEther > 20 ether) { return bonus + 5; }
        return bonus;
    }

    function isICOTimeFinished() public view returns (bool) {
        return currentTime() > ICOEndTime;
    }

    function refund() external {
        require(currentTime() > ICOEndTime && soldTokens < ICOSoftCap);
        uint256 amount = ICOInvestors[msg.sender];
        require(amount > 0);
        ICOInvestors[msg.sender] = 0;
        require(msg.sender.call.gas(3000000).value(amount)());
        balances[msg.sender] = 0;
    }
}

contract WithdrawCrowdsale is ICOPhase {

    function isWithdrawAllowed() public view returns (bool);

    modifier canWithdraw() {
        require(isWithdrawAllowed());
        _;
    }

    function withdraw() external onlyOwner canWithdraw {
        require(msg.sender.call.gas(3000000).value(this.balance)());
    }

    function withdrawAmount(uint256 amount) external onlyOwner canWithdraw {
        uint256 givenAmount = amount;
        if (this.balance < amount) {
            givenAmount = this.balance;
        }
        require(msg.sender.call.gas(3000000).value(givenAmount)());
    }
}

contract Crowdsale is WithdrawCrowdsale {

    using SafeMath for uint256;

    uint public constant bountyAvailabilityTime = (ICOEndTime + 90 days);

    uint256 public constant maxTokenAmount = 100e24; // 100 mln max minting
    uint256 public leftBounty = 100e21; // 100 thounds of token bounty which can be send anytime to any one;

    uint public rateGrazToEther = 1200; // 1200 GRZ = 1 ETH it's start rate can be change.

    uint256 public totalAmount = 0;
    uint public transactionCounter = 0;

    bool public bonusesPayed = false;
    bool public isFailed = false;

    uint256 public constant minAmountForDeal = 1e17;

    modifier canBuy() {
        bool _isPreSalePhase = isPreSalePhase();
        bool _isPreICOPhase = isPreICOPhase();
        bool _isICOPhase = isICOPhase();
        require(_isPreSalePhase || _isPreICOPhase || _isICOPhase);
        require(!isFinished());
        if (isPreSalePhase()) {
            require(canBuyOnPreSale(msg.value));
        }
        _;
    }

    modifier minPayment() {
        require(msg.value >= minAmountForDeal);
        _;
    }

    function Crowdsale() public {
        totalSupply = maxTokenAmount;
        balances[this] = totalSupply;
        blockedUntil = ICOEndTime;
        addCurrencyInternal(0); // add BTC
        addCurrencyInternal(1); // add LTC
    }

    function isFinished() public constant returns (bool) {
        return currentTime() > ICOEndTime || (soldTokens == 82*10**24);
    }

    function checkCrowdsale() public constant returns (bool) {
        return currentTime() > ICOEndTime || (soldTokens == 82*10**24);
    }

    function setRate(uint newRate) external onlyOwner {
        // Can be changed only before phases not in any phase.
        require(!isPreSalePhase() && !isPreICOPhase() && !isICOPhase());
        rateGrazToEther = newRate;
    }

    function isWithdrawAllowed() public view returns (bool) {
        if (currentTime() < ICOStartTime) {
            return soldTokens >= preSaleSoftCap;
        }
        return soldTokens >= ICOSoftCap;
    }

    function() external canBuy minPayment payable {
        uint256 amount = msg.value;
        uint bonus = getBonus(amount);
        uint256 givenTokens = amount.mul(rateGrazToEther).div(100).mul(100 + bonus);
        uint256 providedTokens = transferTokensTo(msg.sender, givenTokens);

        if (givenTokens > providedTokens) {
            uint256 needAmount = providedTokens.mul(100).div(100 + bonus).div(rateGrazToEther);
            require(amount > needAmount);
            require(msg.sender.call.gas(3000000).value(amount - needAmount)());
            amount = needAmount;
        }
        totalAmount = totalAmount.add(amount);
        if (isPreSalePhase()) {
            buyersAddresses[msg.sender].value += amount;
        }
        if (isICOPhase()) {
            ICOInvestors[msg.sender] += amount;
        }

    }

    function manualTransferTokensTo(address to, uint256 givenTokens, uint currency, uint256 amount) external onlyOwner canBuy returns (uint256) {
        return manualTransferTokensToInternal(to, givenTokens, currency, amount);
    }

    function payBounty(address to, uint256 tokens) external onlyOwner {
        require(leftBounty >= tokens && balanceOf(this) >= tokens);
        leftBounty -= tokens;
        require(manualTransfer(to, tokens));
    }

    function getBonus(uint256 amount) public constant returns (uint) {
        if (isPreSalePhase()) { return countPreSaleBonus(amount); }
        if (isPreICOPhase()) { return countPreICOBonus(amount); }
        if (isICOPhase()) { return countICOBonus(amount); }
        return 0;
    }

    function takeTeamBonus() external onlyOwner {
        require(isFinished() && currentTime() > bountyAvailabilityTime);
        require(!bonusesPayed);
        bonusesPayed = true;
        require(transfer(msg.sender, balanceOf(this)));
    }

    function getLimitTokens() internal view returns (uint256) {
        if (isICOPhase()) { return ICOLimit; }
        if (isPreICOPhase()) { return preICOLimit; }
        if (isPreSalePhase()) { return preSaleLimit; }
        return 0;
    }

    function transferTokensTo(address to, uint256 givenTokens) internal returns (uint256) {
        uint256 providedTokens = givenTokens;
        uint256 leftTokens = getLimitTokens().sub(soldTokens);
        if (givenTokens > leftTokens) {
            providedTokens = leftTokens;
        }
        require(manualTransfer(to, providedTokens));
        transactionCounter = transactionCounter + 1;
        soldTokens += providedTokens;
        return providedTokens;
    }
}

contract CrowdsaleTest is Crowdsale {
    uint timeValue = now;

    function currentTime() internal view returns(uint) {
        return timeValue;
    }

    function setCurrentTime(uint value) public returns(uint) {
        timeValue= value;
    }
}