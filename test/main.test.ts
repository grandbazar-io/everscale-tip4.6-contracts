const chai = require("chai");
const assertArrays = require("chai-arrays");
chai.use(assertArrays);
const expect = chai.expect;
const logger = require("mocha-logger");
import { SimpleKeystore, Account } from "everscale-standalone-client/nodejs";
import { zeroAddress, Signer, WalletTypes } from "locklift";
import { add0x, sleep } from "../utils/utils";
import { CollectionsFactory } from "./contracts/CollectionsFactory";
import { CollectionsFactoryBulk } from "./contracts/CollectionsFactoryBulk";
import { CollectionUpgradeable } from "./contracts/CollectionUpgradeable";
import { NftUpgradeable } from "./contracts/NftUpgradeable";
import { NftUpgradeableV2 } from "./contracts/NftUpgradeableV2";
import { NftUpgradeableV3 } from "./contracts/NftUpgradeableV3";
import { CollectionBulkUpgradeable } from "./contracts/CollectionBulkUpgradeable";

describe("Test mint and upgrade", () => {
  let keyPair: Signer;

  let wallets: Account[] = [];
  let walletsKeys: Signer[] = [];

  let collectionsFactory: CollectionsFactory;
  let collectionUpgradeable: CollectionUpgradeable;

  let collectionsFactoryBulk: CollectionsFactoryBulk;
  let collectionBulkUpgradeable: CollectionBulkUpgradeable;

  let nftCodeHash: string;
  let platformCodeHash: string;
  let nftBulkCodeHash: string;
  let bulkPlatformCodeHash: string;
  let nftVersion = 0;
  let collectionVersion = 0;

  let mintPrice: string;
  let bulkMintPrice: string;

  const amountToMint: number = 4;
  const bulkAmountToMint: number = 10;
  let nftItems: NftUpgradeable[] = [];
  let upgradeableV2: NftUpgradeableV2[] = [];
  let upgradeableV3: NftUpgradeableV3[] = [];
  let upgradeableV2Minted: NftUpgradeableV2;
  let upgradeableV3Minted: NftUpgradeableV3;

  let nftBulkItems: NftUpgradeable[] = [];

  const json =
    '{"type":"Basic NFT","name":"GB Merchants","description":"For the most active members of grandbazar.io we created an exclusive GB Merchants collection of 3333 unique NFTs. Owning an NFT will open access to our Collectors Club.","preview":{"source":"https://ipfs.grandbazar.io/ipfs/Qmeaqh1a3zwiiEBkbxaQCrNRSe7EN61Apm6cmEFCuJmoww/","mimetype":"image/jpeg"},"files":[{"source":"https://ipfs.grandbazar.io/ipfs/Qmeaqh1a3zwiiEBkbxaQCrNRSe7EN61Apm6cmEFCuJmoww/","mimetype":"image/jpeg"}],"external_url":"https://grandbazar.io/"}';

  before(async () => {
    const randKeyPair = SimpleKeystore.generateKeyPair();
    await locklift.keystore.addKeyPair("random", randKeyPair);
    keyPair = await locklift.keystore.getSigner("random");
  });

  describe("Deploy root contracts and wallets", async () => {
    it("Create wallets", async () => {
      for (let i = 0; i < 3; i++) {
        await locklift.keystore.addKeyPair(`wallet${i}`, SimpleKeystore.generateKeyPair());
        const keyPair = await locklift.keystore.getSigner(`wallet${i}`);
        let account = await locklift.factory.accounts.addNewAccount({
          type: WalletTypes.EverWallet,
          value: locklift.utils.toNano(10000000),
          publicKey: keyPair.publicKey,
        });

        wallets.push(account.account);
        walletsKeys.push(keyPair);
        logger.log(`Wallet${i} address: ${account.account.address.toString()}`);
      }
    });

    it("Deploy CollectionUpgradeable contract", async () => {
      const collectionArtifacts = locklift.factory.getContractArtifacts("CollectionUpgradeable");
      const collectionPlatformArtifacts = locklift.factory.getContractArtifacts("CollectionPlatform");
      const nftArtifacts = await locklift.factory.getContractArtifacts("NftUpgradeable");
      const indexArtifacts = await locklift.factory.getContractArtifacts("Index");
      const indexBasisArtifacts = await locklift.factory.getContractArtifacts("IndexBasis");
      const platformArtifacts = await locklift.factory.getContractArtifacts("NftPlatform");

      const { contract: collectionsFactoryContract } = await locklift.factory.deployContract({
        contract: "CollectionsFactoryUpgradeable",
        publicKey: keyPair.publicKey,
        initParams: {},
        constructorParams: {
          codeCollection: collectionArtifacts.code,
          codeNft: nftArtifacts.code,
          codeIndex: indexArtifacts.code,
          codeIndexBasis: indexBasisArtifacts.code,
          ownerPubkey: add0x(keyPair.publicKey),
          withdrawalAddress: wallets[0].address,
          creationPrice: locklift.utils.toNano(0.5),
          nftMintingFee: locklift.utils.toNano(0.3),
          collectionPlatformCode: collectionPlatformArtifacts.code,
          nftPlatformCode: platformArtifacts.code,
        },
        value: locklift.utils.toNano(10),
      });

      collectionsFactory = new CollectionsFactory(collectionsFactoryContract);

      logger.log(`CollectionsFactory deployed ${collectionsFactory.address}`);

      expect((await collectionsFactory.contract.getFullState()).state.isDeployed).to.be.true;
    });

    it("Deploy collection", async () => {
      await collectionsFactory.deployCollection(wallets[0], "{}", false);
      await sleep(1000);
      const collectionCreatedEvent = await collectionsFactory.getLastEvent("CollectionCreated");
      collectionUpgradeable = await CollectionUpgradeable.fromAddr(collectionCreatedEvent.collection);

      mintPrice = (await collectionUpgradeable.getFeesInfo()).totalCreationPrice;
      nftCodeHash = await collectionUpgradeable.nftCodeHash();
      platformCodeHash = await collectionUpgradeable.platformCodeHash();
      logger.log(`NftCodeHash: ${nftCodeHash}`);
      logger.log(`PlatformCodeHash: ${platformCodeHash}`);

      logger.log(`CollectionUpgradeable deployed ${collectionUpgradeable.address}`);

      expect((await collectionUpgradeable.contract.getFullState()).state.isDeployed).to.be.true;
    });
  });

  describe("Mint items", async () => {
    it("Mint items and check their props", async () => {
      for (let i = 0; i < amountToMint; i++) {
        await collectionUpgradeable.mint(wallets[0], mintPrice.toString(), json);
      }
      await sleep(5000);

      const accounts = await locklift.provider.getAccountsByCodeHash({
        codeHash: nftCodeHash,
      });

      const totalSuppply = await collectionUpgradeable.totalSupply();

      expect(accounts.accounts.length).to.be.equal(amountToMint);
      expect(+totalSuppply).to.be.equal(amountToMint);

      for (let i = 0; i < accounts.accounts.length; i++) {
        const nftAccount = await NftUpgradeable.fromAddr(accounts.accounts[i]);
        nftItems.push(nftAccount);
        const nftInfo = await nftAccount.getInfo();
        if (i == 0) {
          logger.log(await nftItems[0].getJson());
        }
        expect(nftInfo.manager.toString()).to.be.equal(wallets[0].address.toString());
        expect(nftInfo.owner.toString()).to.be.equal(wallets[0].address.toString());
        expect(nftInfo.collection.toString()).to.be.equal(collectionUpgradeable.address.toString());
        expect(await nftAccount.getJson()).to.equal(json);
      }
    });
  });

  describe("Test NFT upgrade", async () => {
    it("Upgrade NFT code to V2", async () => {
      const nftArtifacts = locklift.factory.getContractArtifacts("NftUpgradeableV2");
      const newData = await locklift.provider.packIntoCell<{ name: string; type: "string" }[]>({
        data: { testAddress: wallets[0].address.toString() },
        structure: [{ name: "testAddress", type: "address" }],
      });
      await collectionsFactory.updateNftCode(nftArtifacts.code, keyPair.publicKey);
      await collectionsFactory.setNewNftData(newData.boc, keyPair.publicKey);
      nftVersion++;

      await sleep(1000);
      expect(+(await collectionsFactory.nftVersion())).to.equal(nftVersion);

      await collectionUpgradeable.updateNftCode(wallets[0]);
      await sleep(2000);

      expect(+(await collectionUpgradeable.nftVersion())).to.equal(nftVersion);
    });

    it("Upgrade NFT from v1 to v2", async () => {
      await nftItems[0].upgrade(wallets[0]);
      await nftItems[1].upgrade(wallets[0]);
      logger.log(`Items: ${nftItems[0].address}, ${nftItems[1].address}`);
      await sleep(2000);

      const upgraded1 = await NftUpgradeableV2.fromAddr(nftItems[0].address);
      const upgraded2 = await NftUpgradeableV2.fromAddr(nftItems[1].address);
      upgradeableV2.push(upgraded1, upgraded2);

      nftItems.shift();
      nftItems.shift();

      for (let upgraded of upgradeableV2) {
        expect(await upgraded.getLicenseURI()).to.equal("licenseURI");
        expect(await upgraded.getLicenseName()).to.equal("licenseName");
        expect(+(await upgraded.getVersion())).to.equal(nftVersion);
      }
    });

    it("Upgrade collection to V2", async () => {
      const collectionArtifacts = locklift.factory.getContractArtifacts("CollectionUpgradeableV2");
      await collectionsFactory.updateCollectionCode(collectionArtifacts.code, keyPair.publicKey);
      collectionVersion++;
      await sleep(1000);
      expect(+(await collectionsFactory.collectionVersion())).to.equal(collectionVersion);

      await collectionUpgradeable.upgrade(wallets[0]);

      await sleep(2000);

      expect(+(await collectionUpgradeable.collectionVersion())).to.equal(collectionVersion);
    });

    it("Mint NFT V2", async () => {
      await collectionUpgradeable.mint(wallets[0], mintPrice.toString(), json);
      await sleep(2000);
      const nftCreatedEvent = await collectionUpgradeable.getLastEvent("NftCreated");
      upgradeableV2Minted = await NftUpgradeableV2.fromAddr(nftCreatedEvent.nft);
      logger.log(`Items: ${upgradeableV2Minted.address}`);

      expect(await upgradeableV2Minted.getLicenseURI()).to.equal("licenseURI");
      expect(await upgradeableV2Minted.getLicenseName()).to.equal("licenseName");
      expect(+(await upgradeableV2Minted.getVersion())).to.equal(nftVersion);
    });

    it("Upgrade NFT code to V3", async () => {
      const nftArtifacts = locklift.factory.getContractArtifacts("NftUpgradeableV3");
      const newData = await locklift.provider.packIntoCell<{ name: string; type: "string" }[]>({
        data: { testAddress: wallets[0].address.toString(), geoData: "geoData" },
        structure: [
          { name: "testAddress", type: "address" },
          { name: "geoData", type: "string" },
        ],
      });
      await collectionsFactory.updateNftCode(nftArtifacts.code, keyPair.publicKey);
      await collectionsFactory.setNewNftData(newData.boc, keyPair.publicKey);
      nftVersion++;

      await sleep(1000);
      expect(+(await collectionsFactory.nftVersion())).to.equal(nftVersion);

      await collectionUpgradeable.updateNftCode(wallets[0]);
      await sleep(1000);

      expect(+(await collectionUpgradeable.nftVersion())).to.equal(nftVersion);
    });

    it("Upgrade NFT from v2 to v3", async () => {
      await upgradeableV2[0].upgrade(wallets[0]);
      logger.log(`Items: ${upgradeableV2[0].address}`);
      await sleep(2000);
      const upgraded1 = await NftUpgradeableV3.fromAddr(upgradeableV2[0].address);
      upgradeableV3.push(upgraded1);
      upgradeableV2.shift();

      expect(await upgraded1.getLicenseURI()).to.equal("licenseURI");
      expect(await upgraded1.getLicenseName()).to.equal("licenseName");
      expect(await upgraded1.getGeoData()).to.equal("geoData");
      expect(+(await upgraded1.getVersion())).to.equal(nftVersion);
    });

    it("Upgrade NFT from v1 to v3", async () => {
      await nftItems[0].upgrade(wallets[0]);
      logger.log(`Items: ${nftItems[0].address}`);
      await sleep(2000);
      const upgraded1 = await NftUpgradeableV3.fromAddr(nftItems[0].address);
      upgradeableV3.push(upgraded1);
      nftItems.shift();

      expect(await upgraded1.getLicenseURI()).to.equal("licenseURI");
      expect(await upgraded1.getLicenseName()).to.equal("licenseName");
      expect(await upgraded1.getGeoData()).to.equal("geoData");
      expect(+(await upgraded1.getVersion())).to.equal(nftVersion);
    });

    it("Upgrade collection to V3", async () => {
      const collectionArtifacts = locklift.factory.getContractArtifacts("CollectionUpgradeableV3");
      await collectionsFactory.updateCollectionCode(collectionArtifacts.code, keyPair.publicKey);
      collectionVersion++;
      await sleep(1000);
      expect(+(await collectionsFactory.collectionVersion())).to.equal(collectionVersion);

      await collectionUpgradeable.upgrade(wallets[0]);

      await sleep(2000);

      expect(+(await collectionUpgradeable.collectionVersion())).to.equal(collectionVersion);
    });

    it("Mint NFT V3", async () => {
      await collectionUpgradeable.mint(wallets[0], mintPrice.toString(), json);
      await sleep(2000);
      const nftCreatedEvent = await collectionUpgradeable.getLastEvent("NftCreated");
      upgradeableV3Minted = await NftUpgradeableV3.fromAddr(nftCreatedEvent.nft);
      logger.log(`Items: ${nftCreatedEvent.nft}`);
      expect(await upgradeableV3Minted.getLicenseURI()).to.equal("licenseURI");
      expect(await upgradeableV3Minted.getLicenseName()).to.equal("licenseName");
      expect(await upgradeableV3Minted.getGeoData()).to.equal("geoData");
      expect(+(await upgradeableV3Minted.getVersion())).to.equal(nftVersion);
    });
  });

  describe("Test bulk collection and nft", async () => {
    it("Deploy CollectionsFactoryBulk contract", async () => {
      const nftArtifacts = await locklift.factory.getContractArtifacts("NftBulkUpgradeable");
      const collectionArtifacts = await locklift.factory.getContractArtifacts("CollectionBulkUpgradeable");
      const indexArtifacts = await locklift.factory.getContractArtifacts("Index");
      const indexBasisArtifacts = await locklift.factory.getContractArtifacts("IndexBasis");

      const collectionPlatformArtifacts = locklift.factory.getContractArtifacts("CollectionPlatform");
      const platformArtifacts = await locklift.factory.getContractArtifacts("NftPlatform");

      const { contract: collectionsFactoryContract } = await locklift.factory.deployContract({
        contract: "CollectionsFactoryBulkUpgradeable",
        publicKey: keyPair.publicKey,
        initParams: {},
        constructorParams: {
          codeCollection: collectionArtifacts.code,
          codeNft: nftArtifacts.code,
          codeIndex: indexArtifacts.code,
          codeIndexBasis: indexBasisArtifacts.code,
          ownerPubkey: add0x(keyPair.publicKey),
          withdrawalAddress: zeroAddress,
          creationPrice: locklift.utils.toNano(1),
          nftMintingFee: locklift.utils.toNano(0.3),
          sendToProxyValue: locklift.utils.toNano(1),
          collectionPlatformCode: collectionPlatformArtifacts.code,
          nftPlatformCode: platformArtifacts.code,
        },
        value: locklift.utils.toNano(10),
      });

      collectionsFactoryBulk = new CollectionsFactoryBulk(collectionsFactoryContract);

      logger.log(`CollectionsFactory deployed ${collectionsFactoryBulk.address}`);

      expect((await collectionsFactoryBulk.contract.getFullState()).state.isDeployed).to.be.true;
    });

    it("Deploy CollectionBulk contract", async () => {
      await collectionsFactoryBulk.deployCollection(wallets[0], "{}", false);
      await sleep(1000);
      const collectionCreatedEvent = await collectionsFactoryBulk.getLastEvent("CollectionCreated");
      collectionBulkUpgradeable = await CollectionBulkUpgradeable.fromAddr(collectionCreatedEvent.collection);

      bulkMintPrice = (await collectionBulkUpgradeable.getFeesInfo()).totalCreationPrice;
      nftBulkCodeHash = await collectionBulkUpgradeable.nftCodeHash();
      bulkPlatformCodeHash = await collectionBulkUpgradeable.platformCodeHash();
      logger.log(`NftBulkCodeHash: ${nftBulkCodeHash}`);
      logger.log(`BulkPlatformCodeHash: ${bulkPlatformCodeHash}`);

      logger.log(`CollectionBulkUpgradeable deployed ${collectionBulkUpgradeable.address}`);

      expect((await collectionBulkUpgradeable.contract.getFullState()).state.isDeployed).to.be.true;
    });

    it("Mint bulk items", async () => {
      const value = +bulkMintPrice * bulkAmountToMint;
      await collectionBulkUpgradeable.mint(wallets[0], value.toString(), json, bulkAmountToMint);

      await sleep(5000);

      const accounts = await locklift.provider.getAccountsByCodeHash({
        codeHash: nftBulkCodeHash,
      });

      const totalSuppply = await collectionBulkUpgradeable.totalSupply();

      expect(accounts.accounts.length).to.be.equal(bulkAmountToMint);
      expect(+totalSuppply).to.be.equal(bulkAmountToMint);

      for (let address of accounts.accounts) {
        const nftAccount = await NftUpgradeable.fromAddr(address);

        expect((await nftAccount.getInfo()).manager.toString()).to.be.equal(wallets[0].address.toString());
        expect(await nftAccount.getLicenseURI()).to.be.equal("licenseURI");
        expect(await nftAccount.getLicenseName()).to.be.equal("licenseName");
      }
    });
  });
});
