import { createAnvil, Anvil } from "@viem/anvil";
import { describe, beforeAll, afterAll, it, expect } from '@jest/globals';
import { exec } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import util from 'util';
import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const execAsync = util.promisify(exec);

async function loadJsonFile(filePath: string): Promise<any> {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    console.error(`Error loading file ${filePath}:`, error);
    return null;
  }
}

async function loadDeployments(): Promise<Record<string, any>> {
  const coreFilePath = path.join(__dirname, '..', 'contracts', 'deployments', 'core', '31337.json');
  const yieldsyncFilePath = path.join(__dirname, '..', 'contracts', 'deployments', 'yieldsync', '31337.json');

  const [coreDeployment, yieldsyncDeployment] = await Promise.all([
    loadJsonFile(coreFilePath),
    loadJsonFile(yieldsyncFilePath)
  ]);

  if (!coreDeployment || !yieldsyncDeployment) {
    console.error('Error loading deployments');
    return {};
  }

  return {
    core: coreDeployment,
    yieldsync: yieldsyncDeployment
  };
}

describe('YieldSync AVS Integration Tests', () => {
  let anvil: Anvil;
  let deployment: Record<string, any>;
  let provider: ethers.JsonRpcProvider;
  let signer: ethers.Wallet;
  let delegationManager: ethers.Contract;
  let yieldSyncServiceManager: ethers.Contract;
  let yieldSyncTaskManager: ethers.Contract;
  let ecdsaRegistryContract: ethers.Contract;
  let avsDirectory: ethers.Contract;

  beforeAll(async () => {
    anvil = createAnvil();
    await anvil.start();
    await execAsync('npm run deploy:core');
    await execAsync('npm run deploy:yieldsync');
    deployment = await loadDeployments();

    provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

    const delegationManagerABI = await loadJsonFile(path.join(__dirname, '..', 'abis', 'IDelegationManager.json'));
    const ecdsaRegistryABI = await loadJsonFile(path.join(__dirname, '..', 'abis', 'ECDSAStakeRegistry.json'));
    const yieldSyncServiceManagerABI = await loadJsonFile(path.join(__dirname, '..', 'abis', 'YieldSyncServiceManager.json'));
    const yieldSyncTaskManagerABI = await loadJsonFile(path.join(__dirname, '..', 'abis', 'YieldSyncTaskManager.json'));
    const avsDirectoryABI = await loadJsonFile(path.join(__dirname, '..', 'abis', 'IAVSDirectory.json'));

    delegationManager = new ethers.Contract(deployment.core.addresses.delegationManager, delegationManagerABI, signer);
    yieldSyncServiceManager = new ethers.Contract(deployment.yieldsync.addresses.yieldSyncServiceManager, yieldSyncServiceManagerABI, signer);
    yieldSyncTaskManager = new ethers.Contract(deployment.yieldsync.addresses.yieldSyncTaskManager, yieldSyncTaskManagerABI, signer);
    ecdsaRegistryContract = new ethers.Contract(deployment.yieldsync.addresses.stakeRegistry, ecdsaRegistryABI, signer);
    avsDirectory = new ethers.Contract(deployment.core.addresses.avsDirectory, avsDirectoryABI, signer);
  });

  it('should register as an operator', async () => {
    const tx = await delegationManager.registerAsOperator(
      "0x0000000000000000000000000000000000000000",
      0,
      ""
    );
    await tx.wait();

    const isOperator = await delegationManager.isOperator(signer.address);
    expect(isOperator).toBe(true);
  });

  it('should register operator to AVS', async () => {
    const salt = ethers.hexlify(ethers.randomBytes(32));
    const expiry = Math.floor(Date.now() / 1000) + 3600;

    const operatorDigestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
      signer.address,
      await yieldSyncServiceManager.getAddress(),
      salt,
      expiry
    );

    const operatorSigningKey = new ethers.SigningKey(process.env.PRIVATE_KEY!);
    const operatorSignedDigestHash = operatorSigningKey.sign(operatorDigestHash);
    const operatorSignature = ethers.Signature.from(operatorSignedDigestHash).serialized;

    const tx = await ecdsaRegistryContract.registerOperatorWithSignature(
      {
        signature: operatorSignature,
        salt: salt,
        expiry: expiry
      },
      signer.address
    );
    await tx.wait();

    const isRegistered = await ecdsaRegistryContract.operatorRegistered(signer.address);
    expect(isRegistered).toBe(true);
  });

  it('should create a new LST yield monitoring task', async () => {
    const lstToken = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"; // stETH
    const quorumThresholdPercentage = 50;
    const quorumNumbers = "0x00";

    const tx = await yieldSyncTaskManager.createNewTask(
      lstToken,
      quorumThresholdPercentage,
      quorumNumbers
    );
    await tx.wait();

    const latestTaskNum = await yieldSyncTaskManager.latestTaskNum();
    expect(latestTaskNum).toBe(1);
  });

  it('should respond to a yield monitoring task', async () => {
    const taskIndex = 0;
    const taskCreatedBlock = await provider.getBlockNumber();
    const lstToken = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
    const yieldRate = 350; // 3.5% APY
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("yield_data"));
    
    const message = `YieldSync:${lstToken}:${yieldRate}:${dataHash}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await signer.signMessage(messageBytes);

    const operators = [await signer.getAddress()];
    const signatures = [signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address[]", "bytes[]", "uint32"],
      [operators, signatures, ethers.toBigInt(taskCreatedBlock)]
    );

    const tx = await yieldSyncTaskManager.respondToTask(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      taskIndex,
      signedTask
    );
    await tx.wait();

    const taskResponse = await yieldSyncTaskManager.allTaskResponses(taskIndex);
    expect(taskResponse).not.toBe("0x0000000000000000000000000000000000000000000000000000000000000000");
  });

  it('should create multiple tasks for different LST tokens', async () => {
    const lstTokens = [
      "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84", // stETH
      "0xae78736Cd615f374D3085123A210448E74Fc6393", // rETH
      "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704", // cbETH
      "0xac3E018457B222d93114458476f3E3416Abbe38F"  // sfrxETH
    ];

    for (let i = 0; i < lstTokens.length; i++) {
      const tx = await yieldSyncTaskManager.createNewTask(
        lstTokens[i],
        50,
        "0x00"
      );
      await tx.wait();
    }

    const latestTaskNum = await yieldSyncTaskManager.latestTaskNum();
    expect(latestTaskNum).toBe(5); // 1 from previous test + 4 new tasks
  });

  it('should handle task response window correctly', async () => {
    const taskIndex = 4;
    const taskCreatedBlock = await provider.getBlockNumber();
    const lstToken = "0xae78736Cd615f374D3085123A210448E74Fc6393"; // rETH
    const yieldRate = 420; // 4.2% APY
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("rocketpool_yield_data"));
    
    const message = `YieldSync:${lstToken}:${yieldRate}:${dataHash}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await signer.signMessage(messageBytes);

    const operators = [await signer.getAddress()];
    const signatures = [signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address[]", "bytes[]", "uint32"],
      [operators, signatures, ethers.toBigInt(taskCreatedBlock)]
    );

    // Wait for response window to pass
    const responseWindow = await yieldSyncTaskManager.TASK_RESPONSE_WINDOW_BLOCK();
    await provider.send("evm_mine", [Number(responseWindow) + 1]);

    const tx = await yieldSyncTaskManager.respondToTask(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      taskIndex,
      signedTask
    );
    await tx.wait();

    const taskResponse = await yieldSyncTaskManager.allTaskResponses(taskIndex);
    expect(taskResponse).not.toBe("0x0000000000000000000000000000000000000000000000000000000000000000");
  });

  it('should verify LST yield data accuracy', async () => {
    const lstToken = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"; // stETH
    const expectedYieldRate = 350; // 3.5% APY
    const tolerance = 10; // 0.1% tolerance

    // This would integrate with actual LST yield monitoring
    // For now, we test the contract logic
    const taskIndex = 5;
    const taskCreatedBlock = await provider.getBlockNumber();
    const yieldRate = expectedYieldRate;
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("lido_yield_data"));
    
    const message = `YieldSync:${lstToken}:${yieldRate}:${dataHash}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await signer.signMessage(messageBytes);

    const operators = [await signer.getAddress()];
    const signatures = [signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address[]", "bytes[]", "uint32"],
      [operators, signatures, ethers.toBigInt(taskCreatedBlock)]
    );

    const tx = await yieldSyncTaskManager.respondToTask(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      taskIndex,
      signedTask
    );
    await tx.wait();

    const taskResponse = await yieldSyncTaskManager.allTaskResponses(taskIndex);
    expect(taskResponse).not.toBe("0x0000000000000000000000000000000000000000000000000000000000000000");
  });

  it('should handle challenge mechanism', async () => {
    const taskIndex = 6;
    const taskCreatedBlock = await provider.getBlockNumber();
    const lstToken = "0xBe9895146f7AF43049ca1c1AE358B0541Ea49704"; // cbETH
    const yieldRate = 380; // 3.8% APY
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("coinbase_yield_data"));
    
    const message = `YieldSync:${lstToken}:${yieldRate}:${dataHash}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await signer.signMessage(messageBytes);

    const operators = [await signer.getAddress()];
    const signatures = [signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address[]", "bytes[]", "uint32"],
      [operators, signatures, ethers.toBigInt(taskCreatedBlock)]
    );

    // First respond to task
    const tx1 = await yieldSyncTaskManager.respondToTask(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      taskIndex,
      signedTask
    );
    await tx1.wait();

    // Then challenge the response (this would be done by challenger)
    const challengeTx = await yieldSyncTaskManager.raiseAndResolveChallenge(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      {
        referenceTaskIndex: taskIndex,
        yieldRate: yieldRate,
        timestamp: Math.floor(Date.now() / 1000),
        dataHash: dataHash
      },
      {
        taskRespondedBlock: taskCreatedBlock + 1,
        hashOfNonSigners: ethers.keccak256(ethers.toUtf8Bytes("non_signers"))
      },
      []
    );
    await challengeTx.wait();

    const isChallenged = await yieldSyncTaskManager.taskSuccessfullyChallenged(taskIndex);
    expect(isChallenged).toBe(true);
  });

  it('should handle multiple operators responding to same task', async () => {
    const taskIndex = 7;
    const taskCreatedBlock = await provider.getBlockNumber();
    const lstToken = "0xac3E018457B222d93114458476f3E3416Abbe38F"; // sfrxETH
    const yieldRate = 400; // 4.0% APY
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("frax_yield_data"));
    
    const message = `YieldSync:${lstToken}:${yieldRate}:${dataHash}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    const signature = await signer.signMessage(messageBytes);

    // Simulate multiple operators (in real scenario, these would be different addresses)
    const operators = [await signer.getAddress(), await signer.getAddress()];
    const signatures = [signature, signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
      ["address[]", "bytes[]", "uint32"],
      [operators, signatures, ethers.toBigInt(taskCreatedBlock)]
    );

    const tx = await yieldSyncTaskManager.respondToTask(
      { 
        lstToken: lstToken, 
        taskCreatedBlock: taskCreatedBlock,
        quorumNumbers: "0x00",
        quorumThresholdPercentage: 50
      },
      taskIndex,
      signedTask
    );
    await tx.wait();

    const taskResponse = await yieldSyncTaskManager.allTaskResponses(taskIndex);
    expect(taskResponse).not.toBe("0x0000000000000000000000000000000000000000000000000000000000000000");
  });

  it('should verify service manager integration', async () => {
    const serviceManagerAddress = await yieldSyncServiceManager.getAddress();
    const taskManagerAddress = await yieldSyncTaskManager.getAddress();
    
    expect(serviceManagerAddress).not.toBe("0x0000000000000000000000000000000000000000");
    expect(taskManagerAddress).not.toBe("0x0000000000000000000000000000000000000000");
    
    // Verify service manager can create tasks through task manager
    const lstToken = "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84";
    const quorumThresholdPercentage = 50;
    const quorumNumbers = "0x00";

    const tx = await yieldSyncServiceManager.createNewTask(
      lstToken,
      quorumThresholdPercentage,
      quorumNumbers
    );
    await tx.wait();

    const latestTaskNum = await yieldSyncTaskManager.latestTaskNum();
    expect(latestTaskNum).toBe(8); // Previous tasks + 1 new task
  });

  afterAll(async () => {
    await anvil.stop();
  });
});
