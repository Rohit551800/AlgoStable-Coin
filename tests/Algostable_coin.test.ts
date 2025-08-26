import { describe, it, expect, beforeAll } from "vitest";
import { Simnet } from "@hirosystems/clarinet-sdk"; // Correct package

let simnet: Simnet;
let address1: string;

describe("example tests", () => {
  beforeAll(async () => {
    // Initialize simnet asynchronously
    simnet = await Simnet.new();
    const accounts = simnet.getAccounts();
    address1 = accounts.get("wallet_1") as string;
  });

  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("shows an example", async () => {
    // callReadOnlyFn is async
    const { result } = await simnet.callReadOnlyFn(
      "counter",
      "get-counter",
      [],
      address1
    );
    expect(result).toBeUint(0);
  });
});
