pragma solidity ^0.4.14;


import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * @title ERC20 Token Interface
 */
//Interface declaration from: https://github.com/ethereum/eips/issues/20
contract ERC20Interface {
    //from: https://github.com/OpenZeppelin/zeppelin-solidity/blob/b395b06b65ce35cac155c13d01ab3fc9d42c5cfb/contracts/token/ERC20Basic.sol
    uint256 public totalSupply; //tokens that can vote, transfer, receive dividend
    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    //from: https://github.com/OpenZeppelin/zeppelin-solidity/blob/b395b06b65ce35cac155c13d01ab3fc9d42c5cfb/contracts/token/ERC20.sol
    function allowance(address owner, address spender) public constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title ERC677 transferAndCall token interface
 * @dev See https://github.com/ethereum/EIPs/issues/677 for specification and
 *      discussion.
 */
contract ERC677 {
    event Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);

    function transferAndCall(address _to, uint _value, bytes _data) public returns (bool success);
}

/**
 * @title Receiver interface for ERC677 transferAndCall
 * @dev See https://github.com/ethereum/EIPs/issues/677 for specification and
 *      discussion.
 */
contract ERC677Receiver {
    function tokenFallback(address _from, uint _value, bytes _data) public;
}


 contract SMARC is ERC677, ERC20Interface {
  
    // constructor
    function SMARC() public {
        owner = msg.sender;
    }
     
    using SafeMath for uint256;
    
    //*************************** Contract details *****************************************
    
    // token metadata
    string public constant name = "SMARC";
    string public constant symbol = "SMARC";
    uint8 public constant decimals = 18;

    // total supply and maximum amount of tokens
    uint256 public   maxSupply = 150000000;
    uint256 public  lockedTokens = 30000000; //tokens for Smart Containers wallet
    
    //time between airdrops
    uint256 public constant redistributionTimeout = 548 days; //18 month


    // token accounting
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    // ownership of contract
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    function transferOwnership(address _newOwner) public onlyOwner{
        require(_newOwner != address(0));
        owner = _newOwner;
    } 
    
    //used in airdrops and voting 
    enum UpdateMode{Wei, Vote, Both} //update mode for the account

//*************************** Minting *****************************************
    
    bool public mintDone = false;
    
    modifier mintingFinished() {
        require(mintDone == true);
        _;
    }
    modifier mintingInProgress() {
        require(mintDone == false);
        _;
    }
    
    // minting functionality, creates tokens and transfers them to ICO participants
    function mint(address[] _recipients, uint256[] _amounts) public mintingInProgress onlyOwner {
        require(_recipients.length == _amounts.length);
        require(_recipients.length < 255);

        for (uint8 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            uint256 amount = _amounts[i];
            

            // enforce maximum token supply
            require(totalSupply + amount >= totalSupply);
            require(totalSupply + amount <= maxSupply);

            balances[recipient] += amount;
            totalSupply += amount;//count how many tokens are sold

            emit Transfer(0, recipient, amount);
        }
    }
    
    
    //stops minting process
    //unlocks voting, airdrops and locking mechanism
    function setMintDone() public mintingInProgress onlyOwner {
        //here we check that we never exceed the 30mio max tokens. This includes
        //the locked and the unlocked tokens.
        require(lockedTokens.add(totalSupply) <= maxSupply);
        mintDone = true; //end the minting
        
        //burn unsold tokens
        burnTokens(maxSupply-totalSupply);// after this maxSupply=totalSupply
    }
    
    
    
    
    //*************************** Locking *****************************************
    //locks all tokens of address in _holders for a given _timeout time
    
    // uses the ACCOUNT struct to prevent locked accounts from voting and getting airdrops
    
    // token lockups, array got replaced by Account Struct in --Voting-
    event TokensLocked(address indexed _holder, uint256 _timeout);
    
    //taken as is from VALID, changed locking mechanism to use Account struct in stead of lockups array
    function lockTokens(address[] _holders, uint256[] _timeouts) public mintingFinished onlyOwner {
        require(_holders.length == _timeouts.length);
        require(_holders.length < 255);

        for (uint8 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];
            uint256 timeout = _timeouts[i];

            // make sure lockup period can not be overwritten once set
            require(now>=account.timeout);

            Account storage account= accounts[holder];
            
            account.timeout=timeout; //lock for "timeout" time, set time when lock expires
            
            emit TokensLocked(holder, timeout);
        }
    }

    
    

    


    //*************************** Voting *****************************************
    /*
     * In addition to the the vode with address/URL and its hash, we also set the value
     * of tokens to be transfered from the locked tokens to the modum account.
     */
     
     
    //taken as is from MODUM added locks for voting in "vote" function and timeout in Account struct
     
     //used to organize voting each adress has an account 
     struct Account {
        uint256 lastProposalStartTime; //For checking at which proposal valueModVote was last updated
        uint256 lastAirdropWei; //For checking after which airDrop bonusWei was last updated
        uint256 lastAirdropClaimTime; //for unclaimed airdrops, re-airdrop
        uint256 bonusWei;      //airDrop/Dividend payout available for withdrawal.
        uint256 votes;  // votes available for voting on active Proposal
        uint256 tokens;      // the owned tokens
        
        uint256 timeout; //for how long tokens are locked
    }
    
    mapping(address => Account) public accounts;

    
    //Proposal for moving founds from holders to Smart Container address at given price.
    struct Proposal {
        string addr;        //Uri for more info
        bytes32 hash;       //Hash of the uri content for checking
        uint256 tokensToBuyBack;      //token to buyback: proposal with 0 amount is invalid
        uint256 marketPrice;    //price at which token are bought
        uint256 startTime;
        uint256 yay;
        uint256 nay;
    }
    
    Proposal public currentProposal;
    
    uint256 public constant votingDuration = 2 weeks;
    uint256 public lastNegativeVoting = 0;
    uint256 public constant blockingDuration = 90 days;

    event Voted(address _addr, bool option, uint256 votes); //called when a vote is casted

     
     // create a proposal to buy tokens from investors at proposed price
    function votingProposal(string _addr, bytes32 _hash, uint256 _value, uint256 _price) public mintingFinished onlyOwner {
        require(!isProposalActive()); // no proposal is active, cannot vote in parallel
        require(_hash != bytes32(0)); //hash need to be set
        require(bytes(_addr).length > 0); //the address need to be set and non-empty

        //in case of negative vote, wait 90 days. If no lastNegativeVoting have
        //occured, lastNegativeVoting is 0 and now is always larger than 14.1.1970
        //(1.1.1970 plus blockingDuration).
        require(now >= lastNegativeVoting.add(blockingDuration));

        currentProposal = Proposal(_addr, _hash, _value, _price, now, 0, 0);
    }
    
    //users can call this to cast a vote
    function vote(bool _vote) public mintingFinished returns (uint256) {
        require(isVoteOngoing()); // vote needs to be ongoing
        Account storage account = updateAccount(msg.sender, UpdateMode.Vote);//set account into voting state
        uint256 votes = account.votes; //available votes
        
        require(now>=account.timeout);//checks that is no longer locked, can vote only if lock is expired
        
        require(votes > 0); //voter must have a vote left, either by not voting yet, or have modum tokens

        if(_vote) {
            currentProposal.yay = currentProposal.yay.add(votes); // add positive vote
        }
        else {
            currentProposal.nay = currentProposal.nay.add(votes); // add negative vote
        }

        account.votes = 0; // no more votes to cast
        Voted(msg.sender, _vote, votes);
        return votes;
    }

    //for user to see how many votes he has
    function showVotes(address _addr) public constant returns (uint256) {
        Account memory account = accounts[_addr];
        if(account.lastProposalStartTime < currentProposal.startTime || // the user did set his token power yet
            (account.lastProposalStartTime == 0 && currentProposal.startTime == 0)) {
            return account.tokens;
        }
        return account.votes;
    }

    // The voting can be claimed by the owner of this contract
    function claimVotingProposal() public onlyOwner{
        require(isProposalActive()); // proposal active
        require(isVotingPhaseOver()); // voting has already ended

        if(currentProposal.yay > currentProposal.nay && currentProposal.tokensToBuyBack > 0) {
            //Vote was accepted
            Account storage account = updateAccount(owner, UpdateMode.Both);
            uint256 tokens = currentProposal.tokensToBuyBack;
            
            // initialize buyback 
            
            
            /*
            account.tokens = account.tokens.add(tokens); //add tokens to owner
            totalSupply = totalSupply.add(tokens); // add tokens to circulating supply
            lockedTokens = lockedTokens.sub(tokens); // remove tokens from locked state
            */
            
        } else if(currentProposal.yay <= currentProposal.nay) {
            //in case of a negative vote, set the time of this negative
            //vote to the end of the negative voting period.
            //This will prevent any new voting to be conducted.
            lastNegativeVoting = currentProposal.startTime.add(votingDuration);
        }
        delete currentProposal; //proposal ended
    }

    function isProposalActive() public constant returns (bool)  {
        return currentProposal.hash != bytes32(0);
    }

    function isVoteOngoing() public constant returns (bool)  {
        return isProposalActive()
            && now >= currentProposal.startTime
            && now < currentProposal.startTime.add(votingDuration);
        //its safe to use it for longer periods:
        //https://ethereum.stackexchange.com/questions/6795/is-block-timestamp-safe-for-longer-time-periods
    }

    function isVotingPhaseOver() public constant returns (bool)  {
        //its safe to use it for longer periods:
        //https://ethereum.stackexchange.com/questions/6795/is-block-timestamp-safe-for-longer-time-periods
        return now >= currentProposal.startTime.add(votingDuration);
    }
    
    //updates an account for voting or airdrop or both. This is required to be able to fix the amount of tokens before
    //a vote or airdrop happend.
    function updateAccount(address _addr, UpdateMode mode) internal returns (Account storage){
        Account storage account = accounts[_addr];
        if(mode == UpdateMode.Vote || mode == UpdateMode.Both) {
            if(isVoteOngoing() && account.lastProposalStartTime < currentProposal.startTime) {// the user did set his token power yet
                account.votes = account.tokens;
                account.lastProposalStartTime = currentProposal.startTime;
            }
        }

        if(mode == UpdateMode.Wei || mode == UpdateMode.Both) {
            uint256 bonus = totalDropPerUnlockedToken.sub(account.lastAirdropWei);
            if(bonus != 0) {
                account.bonusWei = account.bonusWei.add(bonus.mul(account.tokens));
                account.lastAirdropWei = totalDropPerUnlockedToken;
            }
        }

        return account;
    }
    
    
    
    
    
    
    
    //*********************** Airdrop ************************************************
    //default function to pay bonus, anybody that sends eth to this contract will distribute the wei
    //to their token holders
    //Dividend payment / Airdrop
    
    
    
    //taken as is from MODUM, added locks for airdrops in payBonus function
    event Payout(uint256 weiPerToken); //called when an someone payed ETHs to this contract, that can be distributed
    //Airdorp
    uint256 public totalDropPerUnlockedToken = 0;     //totally airdropped eth per unlocked token
    uint256 public rounding = 0;                      //airdrops not accounted yet to make system rounding error proof

    
    //the amount of Ether sent by owner gets payed out to token holders
    function() public payable mintingFinished onlyOwner {
        //ETH payment need to be one-way only, from team to tokenholders, confirmed by Lykke
        payout(msg.value);
    }
    
    //anybody can pay and add address that will be checked if they
    //can be added to the bonus
    function payBonus(address[] _addr) public payable mintingFinished onlyOwner {
        //ETH payment need to be one-way only, from Smart Container to tokenholders, confirmed by Lykke
        uint256 totalWei = 0;
        for (uint8 i=0; i<_addr.length; i++) {
            Account storage account = updateAccount(_addr[i], UpdateMode.Wei);
            if((now >= account.lastAirdropClaimTime + redistributionTimeout) && now>=account.timeout){ //checks tht is no longer locked 
                totalWei += account.bonusWei;
                account.bonusWei = 0;
                account.lastAirdropClaimTime = now;
            } else {
                revert();
            }
        }
        payout(msg.value.add(totalWei));
    }
    
    function payout(uint256 valueWei) internal {
        uint256 value = valueWei.add(rounding); //add old rounding
        rounding = value % totalSupply; //ensure no rounding error
        uint256 weiPerToken = value.sub(rounding).div(totalSupply);
        totalDropPerUnlockedToken = totalDropPerUnlockedToken.add(weiPerToken); //account for locked tokens and add the drop
        emit Payout(weiPerToken);
    }

    function showBonus(address _addr) public constant returns (uint256) {
        uint256 bonus = totalDropPerUnlockedToken.sub(accounts[_addr].lastAirdropWei);
        if(bonus != 0) {
            return accounts[_addr].bonusWei.add(bonus.mul(accounts[_addr].tokens));
        }
        return accounts[_addr].bonusWei;
    }

    function claimBonus() public mintingFinished returns (uint256) {

        Account storage account = updateAccount(msg.sender, UpdateMode.Wei);
        uint256 sendValue = account.bonusWei; //fetch the values

        if(sendValue != 0) {
            account.bonusWei = 0; //set to zero (before, against reentry)
            account.lastAirdropClaimTime = now; //mark as collected now
            msg.sender.transfer(sendValue); //send the bonus to the correct account
            return sendValue;
        }
        return 0;
    }
    
    
    
    
    
    
    //*********************** Burning ************************************************
    //used by owner to destroy tokens(by sending to 0x0) , uses adapted ERC20 transfer function
    function burnTokens(uint256 _amount) public onlyOwner{

        // check balance
        require(balances[msg.sender] >= _amount);
        assert(balances[0x0] + _amount >= balances[0x0]); // receiver balance overflow check

        balances[msg.sender] -= _amount;
        balances[0x0] += _amount;

        emit Transfer(msg.sender, 0x0, _amount);
        
        //decreas circulating supply
        totalSupply=totalSupply.sub(_amount);
        
        //decreas maxSupply
        maxSupply=maxSupply.sub(_amount);
        
    }
    
    
    
    
    

    // ERC20 functionality

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public mintingFinished returns (bool) {
        // prevent some common errors
        require(_to != address(0x0));
        require(_to != address(this));

        Account storage account=accounts[msg.sender];
        require(now>=account.timeout);//checks taht is no longer locked, locked account cant Transfer

        // check balance
        require(balances[msg.sender] >= _value);
        assert(balances[_to] + _value >= balances[_to]); // receiver balance overflow check

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public mintingFinished returns (bool) {
        // prevent some common errors
        require(_to != address(0x0));
        require(_to != address(this));
        
        Account storage account=accounts[_from];
        require(now>=account.timeout);//checks taht is no longer locked, locked account cant Transfer


        // check balance and allowance
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value);
        require(allowance >= _value);
        assert(balances[_to] + _value >= balances[_to]); // receiver balance overflow check

        allowed[_from][msg.sender] -= _value;
        balances[_from] -= _value;
        balances[_to] += _value;

        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        // no check for zero allowance, see NOTES.md

        allowed[msg.sender][_spender] = _value;

        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    // ERC677 functionality

    function transferAndCall(address _to, uint _value, bytes _data) public mintingFinished returns (bool) {
        require(transfer(_to, _value));

        Transfer(msg.sender, _to, _value, _data);

        // call receiver
        if (isContract(_to)) {
            ERC677Receiver receiver = ERC677Receiver(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }
        return true;
    }

    function isContract(address _addr) private view returns (bool) {
        uint len;
        assembly {
            len := extcodesize(_addr)
        }
        return len > 0;
    }
}
