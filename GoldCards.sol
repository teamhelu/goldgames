pragma solidity 0.4.24;

/**

https://goldgames.io          https://goldgames.io        https://goldgames.io


 ██████╗  ██████╗ ██╗     ██████╗  ██████╗ █████╗ ██████╗ ██████╗ ███████╗
██╔════╝ ██╔═══██╗██║     ██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗██╔════╝
██║  ███╗██║   ██║██║     ██║  ██║██║     ███████║██████╔╝██║  ██║███████╗
██║   ██║██║   ██║██║     ██║  ██║██║     ██╔══██║██╔══██╗██║  ██║╚════██║
╚██████╔╝╚██████╔╝███████╗██████╔╝╚██████╗██║  ██║██║  ██║██████╔╝███████║
 ╚═════╝  ╚═════╝ ╚══════╝╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
                                                                          
- by TEAM HELU

**/



import "./GoldGames.sol";

contract ERC721 {

  function approve(address _to, uint _tokenId) public;
  function balanceOf(address _owner) public view returns (uint balance);
  function implementsERC721() public pure returns (bool);
  function ownerOf(uint _tokenId) public view returns (address addr);
  function takeOwnership(uint _tokenId) public;
  function totalSupply() public view returns (uint total);
  function transferFrom(address _from, address _to, uint _tokenId) public;
  function transfer(address _to, uint _tokenId) public;

  event Transfer(address indexed from, address indexed to, uint tokenId);
  event Approval(address indexed owner, address indexed approved, uint tokenId);
}

contract GoldCards is ERC721 {
  using SafeMath for uint;

  /*=================================
  =            MODIFIERS            =
  =================================*/

  modifier onlyCreator() {
    require(msg.sender == creator);
    _;
  }

  modifier notSelf()
  {
    require (msg.sender != address(this));
    _;
  }

  modifier onlyOnSale()
  {
    require (onSale == true);
    _;
  }

  modifier onlyAdministrators()
  {
    require(administrators[msg.sender]);
    _;
  }

  /*=================================
  =             EVENTS              =
  =================================*/

  /// @dev The Birth event is fired whenever a new dividend card comes into existence.
  event Birth(
    uint tokenId,
    string name,
    address owner
  );

  /// @dev The TokenSold event is fired whenever a token (dividend card, in this case) is sold.
  event TokenSold(
    uint tokenId,
    uint oldPrice,
    uint newPrice,
    address prevOwner,
    address winner,
    string name
  );

  /// @dev Transfer event as defined in current draft of ERC721.
  ///  Ownership is assigned, including births.
  event Transfer(
    address from,
    address to,
    uint tokenId
  );

  event DistributeGameDividend(
    uint dividendAmount
  );

  event onBankrollAddressSet(
    address newBankrollAddress
  );

  /*=================================
  =           CONFIGURABLES         =
  =================================*/

  string public constant NAME           = "GoldCards";
  string public constant SYMBOL         = "GGC";


  /*=================================
  =            DATASET              =
  =================================*/

  mapping (uint => address) public      divCardIndexToOwner;
  mapping (uint => uint) public         divCardRateToIndex;
  mapping (address => uint) private     ownershipDivCardCount;
  mapping (uint => address) public      divCardIndexToApproved;
  mapping (uint => uint) private        divCardIndexToPrice;
  mapping (address => bool) internal    administrators;

  address public                        creator;
  address public                        bankrollAddress;
  bool    public                        onSale;
  bool    public                        isToppingUpBankroll;


  address public goldGamesContractAddress;
  GoldGames GoldGamesContract;

  struct Card {
    string name;
    uint percentIncrease;
  }
  Card[] private divCards;

  /*=================================
  =           INTERFACES            =
  =================================*/

  constructor (address _goldGamesContractAddress, address _bankrollAddress)
  public
  {
    creator = msg.sender;
    goldGamesContractAddress = _goldGamesContractAddress;
    GoldGamesContract = GoldGames(goldGamesContractAddress);
    bankrollAddress = _bankrollAddress;

    createDivCard("11%", 100 ether, 11);
    divCardRateToIndex[11] = 0;

    createDivCard("22%", 100 ether, 22);
    divCardRateToIndex[22] = 1;

    createDivCard("33%", 100 ether, 33);
    divCardRateToIndex[33] = 2;

    createDivCard("MASTER", 100 ether, 10);
    divCardRateToIndex[999] = 3;

    onSale = true;
    isToppingUpBankroll = true;
  }

  function createDivCard(string _name, uint _price, uint _percentIncrease)
  public
  onlyCreator
  {
    _createDivCard(_name, creator, _price, _percentIncrease);
  }

  function purchase(uint _divCardId)
  public
  payable
  onlyOnSale
  notSelf
  {
    address oldOwner  = divCardIndexToOwner[_divCardId];
    address newOwner  = msg.sender;

    // Get the current price of the card
    uint currentPrice = divCardIndexToPrice[_divCardId];

    // Making sure token owner is not sending to self
    require(oldOwner != newOwner);

    // Safety check to prevent against an unexpected 0x0 default.
    require(_addressNotNull(newOwner));

    // Making sure sent amount is greater than or equal to the sellingPrice
    require(msg.value >= currentPrice);

    // To find the total profit, we need to know the previous price
    // currentPrice      = previousPrice * (100 + percentIncrease);
    // previousPrice     = currentPrice / (100 + percentIncrease);
    uint percentIncrease = divCards[_divCardId].percentIncrease;
    uint previousPrice   = SafeMath.mul(currentPrice, 100).div(100 + percentIncrease);

    // Calculate total profit and allocate 50% to old owner
    uint totalProfit     = SafeMath.sub(currentPrice, previousPrice);
    uint oldOwnerProfit  = SafeMath.div(totalProfit, 2);
    uint dividendProfit  = SafeMath.sub(totalProfit, oldOwnerProfit);
    oldOwnerProfit       = SafeMath.add(oldOwnerProfit, previousPrice);

    // Refund the sender the excess he sent
    uint purchaseExcess  = SafeMath.sub(msg.value, currentPrice);

    // Raise the price by the percentage specified by the card
    divCardIndexToPrice[_divCardId] = SafeMath.div(SafeMath.mul(currentPrice, (100 + percentIncrease)), 100);

    // Transfer ownership
    _transfer(oldOwner, newOwner, _divCardId);

    if(isToppingUpBankroll && bankrollAddress != address(0))
      bankrollAddress.send(dividendProfit);
    else {
      GoldGamesContract.distributeGameDividend.value(dividendProfit).gas(gasleft())();
      emit DistributeGameDividend(dividendProfit);
    }

    // to card's old owner
    oldOwner.send(oldOwnerProfit);

    msg.sender.transfer(purchaseExcess);
  }

  function receiveDividends(uint _divCardRate)
  public
  payable
  {
    uint _divCardId = divCardRateToIndex[_divCardRate];
    address _regularAddress = divCardIndexToOwner[_divCardId];
    address _masterAddress = divCardIndexToOwner[3];

    uint toMaster = msg.value.div(2);
    uint toRegular = msg.value.sub(toMaster);

    _masterAddress.send(toMaster);
    _regularAddress.send(toRegular);
  }

  /*=================================
  =             GETTERS             =
  =================================*/

  function getDivCard(uint _divCardId)
  public
  view
  returns (string, uint, address)
  {
    Card storage divCard = divCards[_divCardId];
    uint sellingPrice = divCardIndexToPrice[_divCardId];
    address owner = divCardIndexToOwner[_divCardId];

    return (divCard.name, sellingPrice, owner);
  }

  function ownerOf(uint _divCardId)
  public
  view
  returns (address)
  {
    address owner = divCardIndexToOwner[_divCardId];
    require(owner != address(0));
    return owner;
  }

  function priceOf(uint _divCardId)
  public
  view
  returns (uint)
  {
    return divCardIndexToPrice[_divCardId];
  }


  /*=================================
  =     ADMINISTRATION FUNCTIONS    =
  =================================*/

  function startCardSale()
  external
  onlyCreator
  {
    onSale = true;
  }

  function setCreator(address _creator)
  public
  onlyCreator
  {
    require(_creator != address(0));
    creator = _creator;
  }

  function setBankrollAddress(address _bankroll)
  external
  onlyCreator
  {
    bankrollAddress = _bankroll;
    emit onBankrollAddressSet(_bankroll);
  }

  function setToppingUpBankroll(bool flag)
  external
  onlyCreator
  {
    isToppingUpBankroll = flag;
  }


  /*=================================
  =        INTERNAL FUNCTIONS       =
  =================================*/

  function _addressNotNull(address _to)
  private
  pure
  returns (bool)
  {
    return _to != address(0);
  }

  function _approved(address _to, uint _divCardId)
  private
  view
  returns (bool)
  {
    return divCardIndexToApproved[_divCardId] == _to;
  }

  function _createDivCard(string _name, address _owner, uint _price, uint _percentIncrease)
  private
  {
    Card memory _divcard = Card({
      name: _name,
      percentIncrease: _percentIncrease
      });
    uint newCardId = divCards.push(_divcard) - 1;

    // It's probably never going to happen, 4 billion tokens are A LOT, but
    // let's just be 100% sure we never let this happen.
    require(newCardId == uint(uint32(newCardId)));

    emit Birth(newCardId, _name, _owner);

    divCardIndexToPrice[newCardId] = _price;

    // This will assign ownership, and also emit the Transfer event as per ERC721 draft
    _transfer(address(this), _owner, newCardId);
  }

  /// Check for token ownership
  function _owns(address claimant, uint _divCardId)
  private
  view
  returns (bool)
  {
    return claimant == divCardIndexToOwner[_divCardId];
  }

  /// @dev Assigns ownership of a specific Card to an address.
  function _transfer(address _from, address _to, uint _divCardId)
  private
  {
    // Since the number of cards is capped to 2^32 we can't overflow this
    ownershipDivCardCount[_to]++;
    //transfer ownership
    divCardIndexToOwner[_divCardId] = _to;

    // When creating new div cards _from is 0x0, but we can't account that address.
    if (_from != address(0)) {
      ownershipDivCardCount[_from]--;
      // clear any previously approved ownership exchange
      delete divCardIndexToApproved[_divCardId];
    }

    // Emit the transfer event.
    emit Transfer(_from, _to, _divCardId);
  }


  /*=================================
  =         ERC721 COMPLIANCE       =
  =================================*/

  function implementsERC721()
  public
  pure
  returns (bool)
  {
    return true;
  }

  function name()
  public
  pure
  returns (string)
  {
    return NAME;
  }

  function symbol()
  public
  pure
  returns (string)
  {
    return SYMBOL;
  }

  function approve(address _to, uint _tokenId)
  public
  notSelf
  {
    require(_owns(msg.sender, _tokenId));
    divCardIndexToApproved[_tokenId] = _to;
    emit Approval(msg.sender, _to, _tokenId);
  }

  function balanceOf(address _owner)
  public
  view
  returns (uint)
  {
    return ownershipDivCardCount[_owner];
  }

  function takeOwnership(uint _divCardId)
  public
  notSelf
  {
    address newOwner = msg.sender;
    address oldOwner = divCardIndexToOwner[_divCardId];

    require(_addressNotNull(newOwner));

    require(_approved(newOwner, _divCardId));

    _transfer(oldOwner, newOwner, _divCardId);
  }

  function totalSupply()
  public
  view
  returns (uint)
  {
    return divCards.length;
  }

  function transfer(address _to, uint _divCardId)
  public
  notSelf
  {
    require(_owns(msg.sender, _divCardId));
    require(_addressNotNull(_to));

    _transfer(msg.sender, _to, _divCardId);
  }

  function transferFrom(address _from, address _to, uint _divCardId)
  public
  notSelf
  {
    require(_owns(_from, _divCardId));
    require(_approved(_to, _divCardId));
    require(_addressNotNull(_to));

    _transfer(_from, _to, _divCardId);
  }

}
