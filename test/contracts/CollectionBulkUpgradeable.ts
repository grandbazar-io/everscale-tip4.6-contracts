import { Address, Contract, ContractMethods, zeroAddress } from "locklift";
import { Account } from "everscale-standalone-client/nodejs";
import { FactorySource, CollectionBulkUpgradeableAbi } from "../../build/factorySource";

export class CollectionBulkUpgradeable {
  public contract: Contract<FactorySource["CollectionBulkUpgradeable"]>;
  public address: Address;
  public methods: ContractMethods<CollectionBulkUpgradeableAbi>;

  constructor(contract: Contract<FactorySource["CollectionBulkUpgradeable"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  async mint(initiator: Account, value: string, json: string, amount: number) {
    this.contract.methods
      .bulkMint({
        royalty: [[initiator.address, 3]],
        json,
        licenseURI: "licenseURI",
        licenseName: "licenseName",
        amount,
        proxy: zeroAddress,
        payload: ""
      })
      .send({ from: initiator.address, amount: value });
  }

  async updateNftCode(initiator: Account) {
    this.contract.methods
      .requestUpdateNftCode({ sendGasTo: initiator.address })
      .send({ from: initiator.address, amount: locklift.utils.toNano(1) });
  }

  async upgrade(initiator: Account) {
    this.methods
      .requestUpgrade({ sendGasTo: initiator.address })
      .send({ from: initiator.address, amount: locklift.utils.toNano(1) });
  }

  static async fromAddr(addr: Address) {
    const contract = await locklift.factory.getDeployedContract("CollectionBulkUpgradeable", addr);
    return new CollectionBulkUpgradeable(contract);
  }

  async nftVersion() {
    return (await this.methods.nftVersion({ answerId: 0 }).call()).value0;
  }

  async collectionVersion() {
    return (await this.methods.collectionVersion({ answerId: 0 }).call()).value0;
  }

  async nftCodeHash() {
    return BigInt((await this.methods.nftCodeHash({ answerId: 0 }).call()).codeHash).toString(16);
  }

  async platformCodeHash() {
    return BigInt((await this.methods.platformCodeInfo({ answerId: 0 }).call()).codeHash).toString(16);
  }

  async getFeesInfo() {
    return this.methods.getFeesInfo({ answerId: 0 }).call();
  }

  async totalSupply() {
    return (await this.methods.totalSupply({ answerId: 0 }).call()).count;
  }

  async getEvents(eventName: string) {
    return (
      await this.contract.getPastEvents({
        filter: event => event.event === eventName,
      })
    ).events;
  }

  async getLastEvent(eventName: string) {
    const lastEvent = (await this.getEvents(eventName)).shift();

    return lastEvent?.data;
  }
}
