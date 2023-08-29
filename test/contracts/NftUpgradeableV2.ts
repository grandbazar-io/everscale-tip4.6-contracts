import { Address, Contract, ContractMethods } from "locklift";
import { FactorySource, NftUpgradeableV2Abi } from "../../build/factorySource";
import { Account } from "everscale-standalone-client/nodejs";

export class NftUpgradeableV2 {
  public contract: Contract<FactorySource["NftUpgradeableV2"]>;
  public address: Address;
  public methods: ContractMethods<NftUpgradeableV2Abi>;

  constructor(contract: Contract<FactorySource["NftUpgradeableV2"]>) {
    this.contract = contract;
    this.address = this.contract.address;
    this.methods = this.contract.methods;
  }
  async upgrade(initiator: Account) {
    this.methods
      .requestUpgrade({ sendGasTo: initiator.address })
      .send({ from: initiator.address, amount: locklift.utils.toNano(1) });
  }

  async getInfo() {
    return this.methods.getInfo({ answerId: 0 }).call();
  }

  async getVersion() {
    return (await this.methods.version({ answerId: 0 }).call()).value0;
  }

  async getLicenseURI() {
    return (await this.methods.getLicenseURI({ answerId: 0 }).call()).value0;
  }

  async getLicenseName() {
    return (await this.methods.getLicenseName({ answerId: 0 }).call()).value0;
  }

  async getEvents(eventName: string) {
    return (
      await this.contract.getPastEvents({
        filter: event => event.event === eventName,
      })
    ).events;
  }

  static async fromAddr(addr: Address) {
    const contract = await locklift.factory.getDeployedContract("NftUpgradeableV2", addr);
    return new NftUpgradeableV2(contract);
  }

  async getLastEvent(eventName: string) {
    const lastEvent = (await this.getEvents(eventName)).shift();

    return lastEvent?.data;
  }
}
