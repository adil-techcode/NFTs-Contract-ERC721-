// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.5.0/utils/cryptography/MerkleProof.sol";



contract ROYALBWP is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    

// Enum to represent user roles: Normal, Premium, Admin
 enum UserRole {
        Normal,
        Premium,
        Admin
    }

// Struct to store  user data
   struct UserData {
       address userAdd;
       uint    userGLimit;
       bool    isPermission;
       UserRole   role;
   }


   // Struct for  updating NFTs  MedaData  and Fetch Medata as Strct
    struct NFTMetadata{
        string Uri;
        uint token_id;
    }
    
    // Struct for bulk NFTs Minting for Users and Admin
    struct NFTBatch {
        address to;
        uint token_id;
        string uri;
    }

// Struct to represent a phase with its limits and activation status
  struct Phase {
      bool isActive ;
      uint reservedLimit;
      uint permiumUserLimit ;
      uint normalUserLimit;
      mapping(address=>uint) _usersPhaseBalance ;
  }



   mapping(uint => Phase) _Phases;  // Mapping to store phase data
   mapping(address => UserData)   _UserList; // Mapping to store Premium or Normal user data
   mapping(address => bool)  _AdminsList;  // Mapping to store Admin users



  uint totalMintingLimit;  // Contract Total Limit FOr minting nfts
  uint platformMintingLimit;  // this Limit is reserved for admin role only
  uint usersMintingLimit;  // this minting limit used in phases for normal and permiums users
  uint currentPhase;      // current face number for faces 
  bool isTransferable;     //  bool varaible for transfer of nfts is active or inactive
  bytes32 public root;    // Variable for Save Merkle Tree Root  




/**
@dev Modifier that checks if the provided address is valid (not equal to address(0)).
*/

modifier CheckInvalidAddress(address _address) {
  require(_address != address(0), "Invalid address");
  _;
}


/**
@dev Modifier that checks if the user is registered based on their address.
*/
modifier RegistrationRequired(address _address) {
  require(
        _UserList[_address].userAdd != address(0) ,
        "User Registration Required"
    );
  _;
}







               /* Event  */

event UserRegistered(address indexed userAddress,UserRole userRole);
event PhaseCreated( uint phaseIndex,  uint reservedLimit ,uint permiumLimit,uint normalLimit);
event GlobalLimitUpdated(address indexed userAddress,uint newLimit);
event ReservedLimitUpdated(uint phaseIndex,uint newLimit);









    constructor(uint maxlim, uint platlim, bytes32 _root) ERC721("ROYAL-BWP", "RBP") {
        totalMintingLimit = maxlim;
        platformMintingLimit = platlim;
        usersMintingLimit = totalMintingLimit - platformMintingLimit;
        currentPhase = 1;
        root = _root;
    }












/**
@dev Retrieves and returns the maximum minting limit for total minting.
@return The total minting limit as an unsigned integer.
*/


function MaxMinting()  public view  returns(uint) {
    return totalMintingLimit;
}


/**
@dev Retrieves and returns the maximum minting limit for platform minting.
@return The platform minting limit as an unsigned integer.
*/

function PlatformMinting()  public view  returns(uint) {
    return platformMintingLimit;
}

/**
@dev Retrieves and returns the maximum minting limit for user minting.
@return The user minting limit as an unsigned integer.
*/

function UserMinting()  public view  returns(uint) {
    return usersMintingLimit ;
}







/**
 * @dev Registers a user with the specified user role, user address, and limit.
 * @param _userRole The role of the user being registered.
 * @param _userAdd The address of the user being registered.
 * @param _lim The limit associated with the user being registered.
  * Only  owner can call this function.
 */

   function RegisterUser( UserRole  _userRole , address  _userAdd, uint _lim   ) public  onlyOwner  CheckInvalidAddress(_userAdd)    {

 // Check the user is not already registered as a Premium  or Normal  user 
    require(_UserList[msg.sender].userAdd !=  _userAdd , "User Already Registered"); 

    // Check the user is not already registered as an Admin
    require(!_AdminsList[_userAdd], " User Already Registered as Admin!" );
    
   if(_userRole == UserRole.Normal  ||  _userRole == UserRole.Premium  ){  // If Role is Normal or Permium 
    _UserList[_userAdd] = UserData(_userAdd,_lim,false,_userRole);
   }

  else  if(_userRole == UserRole.Admin){ // if role is Admin
      _AdminsList[_userAdd] = true;   
   }
   
   else{
       // Invalid user role provided, revert the transaction
       require(false,"Enter Correct User Role");
   }
  
    // Emit the UserRegistered event
    emit UserRegistered(_userAdd, _userRole);

   }






/**
 * @dev Verify a Premium user .
 * Only the owner can call this function.
 * @param add address of  Premium user to  verified.
 * User Registration Required
 */
function VerifyPermiumUser(address add) public onlyOwner  RegistrationRequired(add) {

   if(_UserList[add].role == UserRole.Premium){
    // Check if the user is not already verified
    require(!_UserList[add].isPermission, "Already Verified");

    // Update the verification status of the Premium user
    _UserList[add].isPermission = true;
   }
   else{
   require(false,"Normal Not Allowed");
   }
}











/*
/**
 * @dev Creates a new phase with the specified limits for reserved, premium, and normal users.
 * @param _reservedLimit The limit for reserved users in the new phase.
 * @param _permiumLimit The limit for premium users in the new phase.
 * @param _normalLimit The limit for normal users in the new phase.
  * Only  owner can call this function.
 */


function createPhase(uint _reservedLimit, uint _permiumLimit, uint _normalLimit) public onlyOwner {
  
    // Check the current phase is not already active
    require(!_Phases[currentPhase].isActive, "Current phase is already active.");
    
    // Check the reserved limit does not exceed the user's minting limit
    require(usersMintingLimit >= _reservedLimit, "Reserved limit cannot exceed the user's minting limit");
    
    // Ensure the current phase has not already been created
    require(
        _Phases[currentPhase].reservedLimit == 0 &&
        _Phases[currentPhase].permiumUserLimit == 0 &&
        _Phases[currentPhase].normalUserLimit == 0,
        "Phase Already Created!"
    );
    
    // Ensure all limits are greater than zero
    require(_reservedLimit > 0 && _permiumLimit > 0 && _normalLimit > 0, "Invalid Limit");
    
    // Update the limits for the current phase
    _Phases[currentPhase].reservedLimit = _reservedLimit;
    _Phases[currentPhase].permiumUserLimit = _permiumLimit;
    _Phases[currentPhase].normalUserLimit = _normalLimit;


     // Emit the PhaseCreated event
    emit PhaseCreated(currentPhase, _reservedLimit, _permiumLimit, _normalLimit);
}









/**
 * @dev Activates the current phase.
  * Only  owner can call this function.
 */
function activePhase() public onlyOwner {
    // Ensure the current phase is not already active
    require(!_Phases[currentPhase].isActive, "Phase is already active.");
    
    // Ensure the current phase has been created
    require(
        _Phases[currentPhase].permiumUserLimit != 0 &&
        _Phases[currentPhase].normalUserLimit != 0,
        "Phase Not Created!"
    );
    
    // Activate the current phase
    _Phases[currentPhase].isActive = true;
}










/**
 * @dev Deactivates the current phase and advances to the next phase.
  * Only  owner can call this function.
 */
function deactivatePhase() public onlyOwner {
    // Ensure the current phase is active
    require(_Phases[currentPhase].isActive, "Phase is not active.");
    
    // Ensure the current phase has been created
    require(
        _Phases[currentPhase].permiumUserLimit != 0 &&
        _Phases[currentPhase].normalUserLimit != 0,
        "Phase Not Created!"
    );
    
    // Deactivate the current phase
    _Phases[currentPhase].isActive = false;
    
    // Move to the next phase  and Never Back to Previous Phase
    currentPhase++;
}








/**
 * @dev Updates the global limit for a user.
 * @param _add The address of the user.
 * @param limit The new global limit for the user.
  * Only  owner can call this function.
  * User Address Registration Required.
  
 */
function updateUserGlobalLimit(address _add, uint limit) public onlyOwner  RegistrationRequired(_add) {
    // Ensure that the provided limit is greater than the user's balance
    require(limit > balanceOf(_add), "The limit must exceed the user's balance.");

        // Update the global limit for a premium user or Normal
        _UserList[_add].userGLimit = limit; 



            // Emit the GlobalLimitUpdated event
    emit GlobalLimitUpdated(_add, limit);         
}











 /**
 * @dev Updates the reserved limit for a Curent phase.
 * @param _lim The new reserved limit to be set.
  * Only  owner can call this function.
 */
function UpdateReservedLimit(uint _lim) public onlyOwner {
    // Ensure that the current phase is active
    require(_Phases[currentPhase].isActive, "Phase Not Active");
    
    // Ensure that the reserved limit does not exceed the user's minting limit
    require(usersMintingLimit >= _lim, "Reserved limit cannot exceed the user's minting limit");
    
    // Ensure that the new limit is greater than the existing reserved limit
    require(_lim > _Phases[currentPhase].reservedLimit, "Limit greater than existing reserved limit");
    
    // Update the reserved limit 
    _Phases[currentPhase].reservedLimit = _lim;


      // Emit the ReservedLimitUpdated event
    emit ReservedLimitUpdated(currentPhase, _lim);
}


/**
 * @dev Internal function to transfer a token from one address to another.
 * Overrides the ERC721 _transfer function.
 * @param from .
 * @param to .
 * @param tokenId .
 */
// function _transfer(address from, address to, uint256 tokenId) internal override(ERC721) {
//     // Check if transfer is currently allowed
//     require(isTransferable, "Transfer is deactivated");

//     // Call the base ERC721 _transfer function
//     super._transfer(from, to, tokenId);
// }






/**
 * @dev allowTransfer() Allows token transfers. Only the contract owner can call this function.
 *  error if transfers are already allowed.
 */
function allowTransfer() public onlyOwner {
    // Check if transfers are already allowed
    require(!isTransferable, "Already Allowed!");

    // Enable token transfers
    isTransferable = true;
}






/**
 * @dev Restricts token transfers. Only the contract owner can call this function.
 *  error if transfers are already restricted.
 */
function restrictTransfer() public onlyOwner {
    // Check if transfers are already restricted
    require(isTransferable, "Already Disallowed!");

    // Disable token transfers
    isTransferable = false;
}









/**
 * @dev Validate the token ID to ensure it does not exceed the total minting limit.
 * @param tokenId The ID of the token to be validated.
 * @return A boolean indicating whether the token ID is valid.
 */
function _validateTokenId(uint tokenId) internal view returns (bool) {
    // Check if the token ID exceeds the total minting limit
    require(tokenId <= totalMintingLimit, "Token ID exceeds the Total Minting Limit");
    
    return true;
}













/**
 * @dev SAFEmint  Mint a new token .
 * @param to The address to  minted .
 * @param uri The URI of the token metadata.
 * @param tokenId The ID of the token to be minted.
 *  User Registration Required
 */
function safeMint(address to, string memory uri, uint tokenId) public  CheckInvalidAddress(to) RegistrationRequired(msg.sender)  {
   
    // Check if the current phase is active
    require(_Phases[currentPhase].isActive, "Phase is Not active or Created!");

    // Check if the User Minting   limit has been exceeded
    require(usersMintingLimit > 0, "Contract  User Minting   limit has been exceeded");

    // Check if the phase mint limit has been exceeded
    require(_Phases[currentPhase].reservedLimit > 0, "Phase mint limit has been exceeded");

    //  Internal Function  Validate the token ID must Less than Total Max Minting Limit
    _validateTokenId(tokenId);

    Phase storage phase = _Phases[currentPhase]; // Phase struct varaibles for Clear Code
    UserData memory user =  _UserList[msg.sender];   // also for same as above               

    // if Premium user minting
    if (user.role == UserRole.Premium ) {

        // Check verification is required for Premium users
        require(user.isPermission, "Verification Required for Premium User");

        // Check if Premium user global limit has been exceeded
        require(balanceOf(msg.sender) < user.userGLimit, "Premium user global limit has been exceeded");

        // Check if Premium user phase limit has been exceeded
        require(phase.permiumUserLimit > phase._usersPhaseBalance[msg.sender], "Premium user phases limit has been exceeded");
    } 
    else {
 
        //    According to Requirement  does not  required for Normal users Verification Thats why its true
        require(true, "Verification Required for Normal User");

        // Check if Normal user global limit has been exceeded
        require(balanceOf(msg.sender) < user.userGLimit, "Normal user global limit has been exceeded");

        // Check if Normal user phase limit has been exceeded
        require(phase.normalUserLimit > phase._usersPhaseBalance[msg.sender], "Normal user phases limit has been exceeded");
    }

    // Update user's phase balance
    phase._usersPhaseBalance[msg.sender]++;

    // Decrease the reserved limit of the current phase
    phase.reservedLimit--;

    // Decrease the total minting limit
    usersMintingLimit--;

    // Mint the token and set its URI
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
}






 












/**
 * @dev Mint multiple NFTs in bulk.
 * @param nftsArray An array of NFTBatch struct representing the NFTs to be minted.
 * Sender Registrayion Required
 */
function mintBulkNfts(NFTBatch[] memory nftsArray) public  RegistrationRequired(msg.sender)  {
  
    // Check if the current phase is active
    require(_Phases[currentPhase].isActive, "Phase is Not active or Created!");

    // Check if the contract user minting limit has been exceeded by Subtract Array Length  
    require(usersMintingLimit - nftsArray.length > 0, "Contract User Minting limit has been exceeded");

    // Check if the phase mint limit has been exceeded  by Subtract Array Length  
    require(_Phases[currentPhase].reservedLimit - nftsArray.length > 0, "Phase mint limit has been exceeded");

 
   Phase storage phase = _Phases[currentPhase]; // Phase struct varaibles for Clear Code
    UserData memory user =  _UserList[msg.sender];   // also for same as above                                // also for same as above 

        if (user.role == UserRole.Premium) {  // if permium
           
            // Check if verification is required for Premium users
            require(user.isPermission, "Verification Required for Premium User");

            // Check if the bulk array length is within the Premium user's global limit
            require(
                user.userGLimit >= balanceOf(msg.sender) + (nftsArray.length),
                "Bulk Array Length must be under Premium User Global Limit"
            );

            // Check if the bulk array length is within the Premium user's phase limit
            require(
                phase.permiumUserLimit >= phase._usersPhaseBalance[msg.sender] + (nftsArray.length),
                "Bulk Array Length must be under Premium User Phase Limit"
            );
        } else {                                           // if normal
           

            // Check if the bulk array length is within the Normal user's global limit
            require(
                user.userGLimit > balanceOf(msg.sender) + (nftsArray.length ),
                "Bulk Array Length must be under Normal User Global Limit"
            );

            // Check if the bulk array length is within the Normal user's phase limit
            require(
                phase.normalUserLimit > phase._usersPhaseBalance[msg.sender] + (nftsArray.length),
                "Bulk Array Length must be under Normal User Phase Limit"
            );
        }

    for (uint i = 0; i < nftsArray.length; i++) {
        // Check if the mint address is valid
        require(nftsArray[i].to != address(0), "Invalid Mint Address");

        // Validate the token ID
        _validateTokenId(nftsArray[i].token_id);

        // Update user's phase balance
        phase._usersPhaseBalance[msg.sender]++;

        // Decrease the reserved limit of the current phase
        phase.reservedLimit--;

        // Decreased The User minting llimit
        usersMintingLimit--;

        // Mint the token and set its URI
        _safeMint(nftsArray[i].to, nftsArray[i].token_id);
        _setTokenURI(nftsArray[i].token_id, nftsArray[i].uri);
    }
}
   
   

    /**
 * @dev Mint multiple NFTs by an admin.
 * Only the addresses listed as admins can call this function.
 * @param _nftsArray An array of NFTBatch struct representing the NFTs to be minted.
 */
function AdminMint(NFTBatch[] memory _nftsArray) public {
    // Check if the caller is listed as an admin
    require(_AdminsList[msg.sender], "Only Admins can Mint NFTs");

    // Check if the array limit is under the platform minting limit
    require(platformMintingLimit > platformMintingLimit - _nftsArray.length, "Array Limit must be under Platform Minting Limit");

    for (uint i = 0; i < _nftsArray.length; i++) {
        // Validate the token ID
        _validateTokenId(_nftsArray[i].token_id);

        // Mint the token and set its URI
        _safeMint(_nftsArray[i].to, _nftsArray[i].token_id);
        _setTokenURI(_nftsArray[i].token_id, _nftsArray[i].uri);

        platformMintingLimit--; // decrease platfor minting limit
    }
}




/**
 * @dev Update the token URI for multiple NFTs in bulk.
 * @param _array An array of NFTMetadata struct representing the NFTs to be updated.
 */
function updateBulkNfts(NFTMetadata[] memory _array) public {
    for (uint i = 0; i < _array.length; i++) {
        // Check if the caller owns the NFT
        if (ownerOf(_array[i].token_id) == msg.sender) {
            // Set the new token URI for the NFT
            _setTokenURI(_array[i].token_id, _array[i].Uri);
        }
    }
}
   



/**
 * @dev Fetch the NFTs owned by a specific address.
 * @param add The address of NFTs will be fetched.
 * @return _nftsArray An array of NFTMetadata struct representing the fetched NFTs.
 */
function FetchNFTS(address add) public view returns (NFTMetadata[] memory _nftsArray) {
    // Check if the owner has any NFTs
    require(balanceOf(add) > 0, "No NFTs");

    // Create a new array to store the NFT metadata
    NFTMetadata[] memory nftsArray = new NFTMetadata[](balanceOf(add));

    for (uint i = 0; i < balanceOf(add); i++) {
        // Get the token ID and URI for each NFT
        uint tokenid = tokenOfOwnerByIndex(add, i);
        string memory uri = tokenURI(tokenid);

        // Create an NFTMetadata struct and add it to the array
        nftsArray[i] = NFTMetadata(uri, tokenid);
    }

    return nftsArray;  // return the strct array
}









  /**
 * @dev function to verify leaf in the tree. 
 */

 function MerkleTree(bytes32[] memory proof) public view returns(bool)  {
     return  MerkleProof.verify(proof, root,keccak256(abi.encodePacked(msg.sender)));
 } 

  /**
 * @dev function to Update Root in the tree.
 */

 function updateRoot(bytes32   _root )  public {
  root = _root;
 }



  /**
 * @dev Pauses all token transfers and approvals.
 * Only owner can call this function.
 * 
 */
function pause() public onlyOwner {
    _pause();
}

/**
 * @dev Unpauses token transfers and approvals.
 * Only  owner can call this function.

 */
function unpause() public onlyOwner {
    _unpause();
}
















    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
            require(isTransferable, "Transfer is deactivated");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }



    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable,ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}