import { Address, Contract, Giver, ProviderRpcClient, Transaction } from "locklift";
import { Ed25519KeyPair } from "everscale-standalone-client";

type AbiType = typeof giverV2Abi & { version?: string };

// Reimplements this class if you need to use custom giver contract
export class SimpleGiver implements Giver {
  public giverContract: Contract<AbiType>;

  constructor(ever: ProviderRpcClient, readonly keyPair: Ed25519KeyPair, address: string) {
    const giverAddr = new Address(address);
    this.giverContract = new ever.Contract(giverV2Abi, giverAddr);
  }

  public async sendTo(sendTo: Address, value: string): Promise<{ transaction: Transaction; output?: {} }> {
    return this.giverContract.methods
      .sendTransaction({
        value: value,
        dest: sendTo,
        bounce: false,
      })
      .sendExternal({ publicKey: this.keyPair.publicKey });
  }
}

export class GiverV3 extends SimpleGiver {
  constructor(ever: ProviderRpcClient, readonly keyPair: Ed25519KeyPair, address: string) {
    super(ever, keyPair, address);
    const giverAddr = new Address(address);
    this.giverContract = new ever.Contract(giverV3Abi, giverAddr);
  }
}

const giverV2Abi = {
  "ABI version": 2,
  header: ["time", "expire"],
  functions: [
    {
      name: "upgrade",
      inputs: [{ name: "newcode", type: "cell" }],
      outputs: [],
    },
    {
      name: "sendTransaction",
      inputs: [
        { name: "dest", type: "address" },
        { name: "value", type: "uint128" },
        { name: "bounce", type: "bool" },
      ],
      outputs: [],
    },
    {
      name: "getMessages",
      inputs: [],
      outputs: [
        {
          components: [
            { name: "hash", type: "uint256" },
            { name: "expireAt", type: "uint64" },
          ],
          name: "messages",
          type: "tuple[]",
        },
      ],
    },
    {
      name: "constructor",
      inputs: [],
      outputs: [],
    },
  ],
  events: [],
} as const;

const giverV3Abi = {
  ...giverV2Abi,
  version: "2.2",
} as const;

export class GiverWallet implements Giver {
  public giverContract: Contract<typeof giverWallet>;

  constructor(ever: ProviderRpcClient, readonly keyPair: Ed25519KeyPair, address: string) {
    const giverAddr = new Address(address);
    this.giverContract = new ever.Contract(giverWallet, giverAddr);
  }

  public async sendTo(sendTo: Address, value: string): Promise<{ transaction: Transaction; output?: {} }> {
    return this.giverContract.methods
      .sendTransaction({
        value: value,
        dest: sendTo,
        bounce: false,
        flags: 3,
        payload: "",
      })
      .sendExternal({ publicKey: this.keyPair.publicKey });
  }
}

const giverWallet = {
  "ABI version": 2,
  header: ["pubkey", "time", "expire"],
  functions: [
    {
      name: "sendTransaction",
      inputs: [
        { name: "dest", type: "address" },
        { name: "value", type: "uint128" },
        { name: "bounce", type: "bool" },
        { name: "flags", type: "uint8" },
        { name: "payload", type: "cell" },
      ],
      outputs: [],
    },
  ],
  events: [],
} as const;
