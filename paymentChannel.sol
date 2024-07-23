//SPDX-License-Identifier:MIT
pragma solidity >=0.7.0 <0.9.0;

contract Owned{
    address payable owner;
    constructor(){
        owner=payable(msg.sender);
    }
}

contract Freezable is Owned{
    bool private _frozen=false;

    modifier notFrozen(){
        require(!_frozen,"Inactive Contract");
        _;
    }

    function freeze() internal{
        if(msg.sender==owner)
            _frozen=true;
    }
}

contract ReceiverPays is Freezable {
    mapping(uint256=>bool) usedNonce;

    constructor() payable {}

    function claimPayment(uint256 amount,uint256 nonce,bytes memory signature) 
       external 
       notFrozen
       {
        require(!usedNonce[nonce]);
        usedNonce[nonce]=true;
       

       //this recreates the message that was signed on the client
       bytes32 message=prefixed(keccak256(abi.encodePacked(msg.sender,amount,nonce,this)));
       require(recoverSigner(message,signature)==owner);
       payable(msg.sender).transfer(amount);
       }

       //Freeze the contract and reclaim the funds
       function shutDown()
        external 
        notFrozen
        {
            require(msg.sender==owner);
            freeze();
            payable(msg.sender).transfer(address(this).balance);
            
        }

        ///signature methods
        function splitSignature(bytes memory sig)
          internal
          pure 
          returns(uint8 v,bytes32 r,bytes32 s)
          {
            require(sig.length==65);

            assembly{
                //first 32 bytes,after the length prefix.
                r:=mload(add(sig,32))
                //second 32 bytes
                s:=mload(add(sig,64))
                //final bytes (first byte of the next 32 bytes
                v:=byte(0,mload(add(sig,96)))
            }

            return (v,r,s);
          }

          function recoverSigner(bytes32 message,bytes memory sig)
            internal 
            pure 
            returns(address)
            {
                (uint8 v,bytes32 r,bytes32 s)=splitSignature(sig);
                return ecrecover(message, v, r, s);
            }

            ///builds a prefixed hash to mimic the behavior of eth_sign.
            function prefixed(bytes32 hash)
              internal 
              pure 
              returns(bytes32)
              {
                return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32",hash));
              }
}