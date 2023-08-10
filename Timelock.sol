// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CookieTimeLock {
    error NotOwnerError();
    error AlreadyQueuedError(bytes32 txId);
    error NotQueuedError(bytes32 txId);
    error TimestampNotPassedError(uint blockTimestmap, uint timestamp);
    error TxFailedError();

    event Queue(
        bytes32 indexed txId,
        address indexed target,
        string func,
        bytes data,
        uint timestamp
    );
    event Execute(
        bytes32 indexed txId,
        address indexed target,
        string func,
        bytes data,
        uint timestamp
    );
    event Cancel(bytes32 indexed txId);

    uint public constant TIME_DELAY = 43200; // seconds

    address public targetContract;
    address public owner;

    // tx id => queued
    mapping(bytes32 => bool) public queued;

    constructor(address _targetContract) {
        targetContract = _targetContract;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwnerError();
        }
        _;
    }

    receive() external payable {}

    function getTxId(
        string memory _func,
        bytes memory _data,
        uint _timestamp
    ) public view returns (bytes32) {
        return keccak256(abi.encode(targetContract, _func, _data, _timestamp));
    }

    function queueAdd(uint256 _allocPoint, address _lpToken, uint16 _depositFeeBP, bool _withUpdate) external onlyOwner returns (bytes32 txId) {
        string memory _func = "add(uint256,address,uint16,bool)";
        uint _timestamp = block.timestamp + TIME_DELAY;
        bytes memory _data = abi.encodeWithSignature(_func, _allocPoint, _lpToken, _depositFeeBP, _withUpdate);
        txId = getTxId(_func, _data, _timestamp);
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        queued[txId] = true;

        emit Queue(txId, targetContract,  _func, _data, _timestamp);
    }

    function queueSet(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) external onlyOwner returns (bytes32 txId) {
        string memory _func = "set(uint256,uint256,uint16,bool)";
        uint _timestamp = block.timestamp + TIME_DELAY;
        bytes memory _data = abi.encodeWithSignature(_func, _pid, _allocPoint, _depositFeeBP, _withUpdate);
        txId = getTxId(_func, _data, _timestamp);
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        queued[txId] = true;

        emit Queue(txId, targetContract,  _func, _data, _timestamp);
    }

    function queueUpdateEmissions(uint256 CookiePerBlock) external onlyOwner returns (bytes32 txId) {
        string memory _func = "updateEmissionRate(uint256)";
        uint _timestamp = block.timestamp + TIME_DELAY;
        bytes memory _data = abi.encodeWithSignature(_func, CookiePerBlock);
        txId = getTxId(_func, _data, _timestamp);
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        queued[txId] = true;

        emit Queue(txId, targetContract,  _func, _data, _timestamp);
    }

    function queueTransferOwnership(address _newOwner) external onlyOwner returns (bytes32 txId) {
        string memory _func = "transferOwnership(address)";
        uint _timestamp = block.timestamp + TIME_DELAY;
        bytes memory _data = abi.encodeWithSignature(_func, _newOwner);
        txId = getTxId(_func, _data, _timestamp);
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        queued[txId] = true;

        emit Queue(txId, targetContract,  _func, _data, _timestamp);
    }

    function queue(string calldata _func, bytes calldata _data) external onlyOwner returns (bytes32 txId) {
        uint _timestamp = block.timestamp + TIME_DELAY;
        txId = getTxId(_func, _data, _timestamp);
        if (queued[txId]) {
            revert AlreadyQueuedError(txId);
        }
        queued[txId] = true;

        emit Queue(txId, targetContract,  _func, _data, _timestamp);
    }

    function execute(
        string calldata _func,
        bytes calldata _data,
        uint _timestamp
    ) external onlyOwner returns (bytes memory) {
        bytes32 txId = getTxId(_func, _data, _timestamp);
        if (!queued[txId]) {
            revert NotQueuedError(txId);
        }

        if (block.timestamp < _timestamp) {
            revert TimestampNotPassedError(block.timestamp, _timestamp);
        }

        queued[txId] = false;

        // prepare data
        bytes memory data;
        data = _data;

        // call target
        (bool ok, bytes memory res) = targetContract.call{value: 0}(data);
        if (!ok) {
            revert TxFailedError();
        }

        emit Execute(txId, targetContract, _func, _data, _timestamp);

        return res;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        if (!queued[_txId]) {
            revert NotQueuedError(_txId);
        }

        queued[_txId] = false;

        emit Cancel(_txId);
    }
}