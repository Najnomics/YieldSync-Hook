import { config } from 'dotenv';

// Load environment variables
config();

// Set default test environment variables
process.env.RPC_URL = process.env.RPC_URL || 'http://localhost:8545';
process.env.PRIVATE_KEY = process.env.PRIVATE_KEY || '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

// Increase timeout for blockchain tests
jest.setTimeout(30000);

// Global test setup
beforeAll(async () => {
  console.log('Setting up YieldSync AVS integration tests...');
});

afterAll(async () => {
  console.log('Cleaning up YieldSync AVS integration tests...');
});

