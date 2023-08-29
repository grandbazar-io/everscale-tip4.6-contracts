import { Address, Contract, ContractMethods, zeroAddress } from "locklift";
import { FactorySource, CollectionsFactoryBulkUpgradeableAbi } from "../../build/factorySource";
import { Account } from "everscale-standalone-client/nodejs";

export class CollectionsFactoryBulk {
  public contract: Contract<FactorySource["CollectionsFactoryBulkUpgradeable"]>;
  public address: Address;
  public methods: ContractMethods<CollectionsFactoryBulkUpgradeableAbi>;

  constructor(contract: Contract<FactorySource["CollectionsFactoryBulkUpgradeable"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }

  async deployCollection(initiator: Account, json: string, isProtected: boolean) {
    const value = (await this.getFeesInfo()).totalCreationPrice;

    this.contract.methods
      .deployCollection({
        json,
        sendGasTo: initiator.address,
        isProtected,
      })
      .send({ from: initiator.address, amount: value });
  }

  async updateNftCode(code: string, publicKey: string) {
    this.contract.methods.updateNftCode({ code }).sendExternal({ publicKey });
  }

  async setNewNftData(newData: string, publicKey: string) {
    this.contract.methods.setNewNftData({ newData }).sendExternal({ publicKey });
  }

  async updateCollectionCode(newCode: string, publicKey: string) {
    this.methods.updateCollectionCode({ code: newCode }).sendExternal({ publicKey });
  }

  async setCollectionData(newData: string, publicKey: string) {
    this.methods.setNewCollectionData({ newData }).sendExternal({ publicKey });
  }

  async nftVersion() {
    return (await this.methods.nftVersion({ answerId: 0 }).call()).value0;
  }

  async collectionVersion() {
    return (await this.methods.collectionVersion({answerId: 0}).call()).value0;
  }

  async getFeesInfo() {
    return this.methods.getFeesInfo({ answerId: 0 }).call();
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
