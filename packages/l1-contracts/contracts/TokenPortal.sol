pragma solidity >=0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Messaging
import {IRegistry} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IRegistry.sol";
import {IInbox} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IInbox.sol";
import {IOutbox} from "@aztec/l1-contracts/src/core/interfaces/messagebridge/IOutbox.sol";
import {DataStructures} from "@aztec/l1-contracts/src/core/libraries/DataStructures.sol";
import {Hash} from "@aztec/l1-contracts/src/core/libraries/Hash.sol";

contract TokenPortal {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    IRegistry public registry;
    IERC20 public underlying;
    bytes32 public l2Bridge;

    address public zeronymAttester = 0xa74772264f896843c6346ceA9B13e0128A1d3b5D;
    uint256 public cleanHandsCircuitId =
        0x1c98fc4f7f1ad3805aefa81ad25fa466f8342292accf69566b43691d12742a19;

    function initialize(
        address _registry,
        address _underlying,
        bytes32 _l2Bridge
    ) external {
        registry = IRegistry(_registry);
        underlying = IERC20(_underlying);
        l2Bridge = _l2Bridge;
    }

    function verifySignature(
        uint256 circuitId,
        uint256 actionId,
        address userAddress,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 digest = keccak256(
            abi.encodePacked(circuitId, actionId, userAddress)
        );

        bytes32 personalSignPreimage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
        );

        (address recovered, ECDSA.RecoverError err, bytes32 _sig) = ECDSA
            .tryRecover(personalSignPreimage, signature);

        return recovered == zeronymAttester;
    }

    /**
     * @notice Deposit funds into the portal and adds an L2 message which can only be consumed publicly on Aztec
     * @param _to - The aztec address of the recipient
     * @param _amount - The amount to deposit
     * @param _secretHash - The hash of the secret consumable message. The hash should be 254 bits (so it can fit in a Field element)
     * @param _actionId - The actionId of the message
     * @param _attesterSig - The signature of the attester
     * @return The key of the entry in the Inbox
     */
    function depositToAztecPublic(
        bytes32 _to,
        uint256 _amount,
        bytes32 _secretHash,
        uint256 _actionId,
        bytes memory _attesterSig
    ) external returns (bytes32) {
        // Verify the signature
        require(
            verifySignature(
                cleanHandsCircuitId,
                _actionId,
                msg.sender,
                _attesterSig
            ),
            "Signature verification failed"
        );

        // Preamble
        IInbox inbox = registry.getInbox();
        DataStructures.L2Actor memory actor = DataStructures.L2Actor(
            l2Bridge,
            1
        );

        // Hash the message content to be reconstructed in the receiving contract
        bytes32 contentHash = Hash.sha256ToField(
            abi.encodeWithSignature(
                "mint_public(bytes32,uint256)",
                _to,
                _amount
            )
        );

        // Hold the tokens in the portal
        underlying.safeTransferFrom(msg.sender, address(this), _amount);

        // Send message to rollup
        return inbox.sendL2Message(actor, contentHash, _secretHash);
    }

    /**
     * @notice Deposit funds into the portal and adds an L2 message which can only be consumed privately on Aztec
     * @param _secretHashForRedeemingMintedNotes - The hash of the secret to redeem minted notes privately on Aztec. The hash should be 254 bits (so it can fit in a Field element)
     * @param _amount - The amount to deposit
     * @param _secretHashForL2MessageConsumption - The hash of the secret consumable L1 to L2 message. The hash should be 254 bits (so it can fit in a Field element)
     * @param _actionId - The actionId of the message
     * @param _attesterSig - The signature of the attester
     * @return The key of the entry in the Inbox
     */
    function depositToAztecPrivate(
        bytes32 _secretHashForRedeemingMintedNotes,
        uint256 _amount,
        bytes32 _secretHashForL2MessageConsumption,
        uint256 _actionId,
        bytes memory _attesterSig
    ) external returns (bytes32) {
        // Verify the signature
        require(
            verifySignature(
                cleanHandsCircuitId,
                _actionId,
                msg.sender,
                _attesterSig
            ),
            "Signature verification failed"
        );

        // Preamble
        IInbox inbox = registry.getInbox();
        DataStructures.L2Actor memory actor = DataStructures.L2Actor(
            l2Bridge,
            1
        );

        // Hash the message content to be reconstructed in the receiving contract
        bytes32 contentHash = Hash.sha256ToField(
            abi.encodeWithSignature(
                "mint_private(bytes32,uint256)",
                _secretHashForRedeemingMintedNotes,
                _amount
            )
        );

        // Hold the tokens in the portal
        underlying.safeTransferFrom(msg.sender, address(this), _amount);

        // Send message to rollup
        return
            inbox.sendL2Message(
                actor,
                contentHash,
                _secretHashForL2MessageConsumption
            );
    }

    /**
     * @notice Withdraw funds from the portal
     * @dev Second part of withdraw, must be initiated from L2 first as it will consume a message from outbox
     * @param _recipient - The address to send the funds to
     * @param _amount - The amount to withdraw
     * @param _withCaller - Flag to use `msg.sender` as caller, otherwise address(0)
     * @param _l2BlockNumber - The address to send the funds to
     * @param _leafIndex - The amount to withdraw
     * @param _path - Flag to use `msg.sender` as caller, otherwise address(0)
     * @param _actionId - The actionId of the message
     * @param _attesterSig - The signature of the attester
     * Must match the caller of the message (specified from L2) to consume it.
     */
    function withdraw(
        address _recipient,
        uint256 _amount,
        bool _withCaller,
        uint256 _l2BlockNumber,
        uint256 _leafIndex,
        bytes32[] calldata _path,
        uint256 _actionId,
        bytes memory _attesterSig
    ) external {
        // Verify the signature
        require(
            verifySignature(
                cleanHandsCircuitId,
                _actionId,
                msg.sender,
                _attesterSig
            ),
            "Signature verification failed"
        );

        DataStructures.L2ToL1Msg memory message = DataStructures.L2ToL1Msg({
            sender: DataStructures.L2Actor(l2Bridge, 1),
            recipient: DataStructures.L1Actor(address(this), block.chainid),
            content: Hash.sha256ToField(
                abi.encodeWithSignature(
                    "withdraw(address,uint256,address)",
                    _recipient,
                    _amount,
                    _withCaller ? msg.sender : address(0)
                )
            )
        });

        IOutbox outbox = registry.getOutbox();

        outbox.consume(message, _l2BlockNumber, _leafIndex, _path);

        underlying.transfer(_recipient, _amount);
    }
}
