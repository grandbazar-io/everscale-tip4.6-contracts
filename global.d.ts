import { FactorySource } from "../../build/factorySource";
import { Account } from "locklift/build/factory";

type AccountType = Account<FactorySource["Wallet"]>;
