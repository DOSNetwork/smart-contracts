var Staking = artifacts.require("Staking");
var Bridge = artifacts.require("DOSAddressBridge");
var Ttk = artifacts.require("TestToken");
const truffleAssert = require("truffle-assertions");
const {
  BN,
  time,
  constants,
  balance,
  expectEvent,
  expectRevert
} = require("@openzeppelin/test-helpers");

contract("Staking", async accounts => {
  it("test newNode - node has no enough balance", async () => {
    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    bridge.setProxyAddress(accounts[0]);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      ttk.address,
      bridge.address
    );

    ttk.transfer(accounts[1], 30000, { from: accounts[0] });
    let balance = await ttk.balanceOf(accounts[1]);
    assert.equal(balance.valueOf(), 30000);
    ttk.approve(staking.address, -1, { from: accounts[1] });
    try {
      let tx = await staking.newNode(accounts[1], 50000, 0, 1, "test", {
        from: accounts[1]
      });
      assert.fail(true, false, "The function should throw error");
    } catch (err) {
      assert.include(String(err), "revert", "");
    }
  });
  it("test updateNodeStaking", async () => {
    let stakedTokenPerNode = 50000;
    let proxyAddr = accounts[11];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodeStakingAddr = accounts[1];
    let nodeAddr = accounts[1];

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));

    await ttk.transfer(nodeStakingAddr, value, { from: tokenPool });
    await ttk.approve(staking.address, -1, { from: nodeStakingAddr });
    await staking.newNode(nodeAddr, value, 0, 10, "test", {
      from: nodeStakingAddr
    });
    let apr = await staking.getCurrentAPR();
    assert.equal(apr, 8000, "After 1 year, delegator balance should be 7200 ");

    for (var i = 1; i <= 9; i++) {
      await ttk.transfer(nodeStakingAddr, value, { from: tokenPool });
      await staking.updateNodeStaking(nodeAddr, value, 0, 10, {
        from: nodeStakingAddr
      });
    }
    let total = await staking.totalStakedTokens.call();
    assert.equal(total.toString(), 0, "totalStakedTokens should be 0 ");

    await staking.nodeStart(nodeAddr, {
      from: proxyAddr
    });
    total = await staking.totalStakedTokens.call();
    assert.equal(
      total.toString(),
      500000000000000000000000,
      "totalStakedTokens should be 500000000000000000000000 "
    );
  });
  it("test uptime", async () => {
    let stakedTokenPerNode = 500000;
    let proxyAddr = accounts[14];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));

    await ttk.transfer(accounts[1], value, { from: tokenPool });
    await ttk.approve(staking.address, -1, { from: accounts[1] });
    await staking.newNode(accounts[1], value, 0, 1, "test", {
      from: accounts[1]
    });
    await staking.nodeStart(accounts[1], { from: proxyAddr });

    let advancement = 86400 * 1; // 1 Days
    await time.increase(advancement);
    await staking.nodeStop(accounts[1], { from: proxyAddr });
    advancement = 86400 * 1; // 1 Days
    await time.increase(advancement);
    let node = await staking.nodes.call(accounts[1]);
    let uptime = await staking.getNodeUptime(accounts[1]);
    assert.equal(
      Math.round(uptime.toNumber() / (60 * 60 * 24)),
      1,
      "After 2 days, uptime should be 1 day "
    );
  });
  it("test nodeClaimReward", async () => {
    let stakedTokenPerNode = 500000;
    let proxyAddr = accounts[14];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodes = 13;

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));

    let apr = await staking.getCurrentAPR();
    let totalReward = 0;
    let nodeBalance = 0;

    for (var i = 1; i <= nodes; i++) {
      await ttk.transfer(accounts[i], value, { from: tokenPool });
      await ttk.approve(staking.address, -1, { from: accounts[i] });
      let tx = await staking.newNode(accounts[i], value, 0, 1, "test", {
        from: accounts[i]
      });
      await staking.nodeStart(accounts[i], {
        from: proxyAddr
      });
    }

    let advancement = 86400 * 365; // 365 Days
    await time.increase(advancement);
    for (var i = 1; i <= nodes; i++) {
      await staking.nodeClaimReward(accounts[i], { from: accounts[i] });
      let balance = await ttk.balanceOf(accounts[i]);
      nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
      totalReward = totalReward + nodeBalance;
      assert.equal(
        nodeBalance,
        400000,
        "After 1 year, nodeBalance should be 500000 * 0.8 "
      );
    }
  });
  it("test nodeClaimReward - node only runs 73 days during a year", async () => {
    let stakedTokenPerNode = 500000;
    let proxyAddr = accounts[14];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodes = 13;

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));

    let apr = await staking.getCurrentAPR();
    let totalReward = 0;
    let nodeBalance = 0;

    for (var i = 1; i <= nodes; i++) {
      await ttk.transfer(accounts[i], value, { from: tokenPool });
      await ttk.approve(staking.address, -1, { from: accounts[i] });
      let tx = await staking.newNode(accounts[i], value, 0, 1, "test", {
        from: accounts[i]
      });
    }

    for (var i = 1; i <= nodes; i++) {
      await staking.nodeStart(accounts[i], {
        from: proxyAddr
      });
    }
    let advancement = 86400 * 20; // 20 Days
    await time.increase(advancement);

    for (var i = 1; i <= nodes; i++) {
      await staking.nodeStop(accounts[i], {
        from: proxyAddr
      });
    }
    advancement = 86400 * 100; // 100 Days
    await time.increase(advancement);

    for (var i = 1; i <= nodes; i++) {
      await staking.nodeStart(accounts[i], {
        from: proxyAddr
      });
    }
    advancement = 86400 * 53; // 53 Days
    await time.increase(advancement);

    for (var i = 1; i <= nodes; i++) {
      await staking.nodeStop(accounts[i], {
        from: proxyAddr
      });
    }
    advancement = 86400 * 192; // 1 Days
    await time.increase(advancement);

    totalReward = 0;
    for (var i = 1; i <= nodes; i++) {
      await staking.nodeClaimReward(accounts[i], { from: accounts[i] });
      let balance = await ttk.balanceOf(accounts[i]);
      nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
      totalReward = totalReward + nodeBalance;
      assert.equal(
        nodeBalance,
        80000,
        "After 1 year, nodeBalance should be 500000 * 0.8 / (365 / 73) "
      );
    }
  });
  it("test delegatorClaimReward", async () => {
    let stakedTokenPerNode = 50000;
    let proxyAddr = accounts[11];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodeStakingAddr = accounts[1];
    let nodeAddr = accounts[1];
    let delegater = 9;

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));
    await ttk.transfer(nodeStakingAddr, value, { from: tokenPool });
    await ttk.approve(staking.address, -1, { from: nodeStakingAddr });
    await staking.newNode(nodeAddr, value, 0, 10, "test", {
      from: nodeStakingAddr
    });

    await staking.nodeStart(nodeAddr, {
      from: proxyAddr
    });

    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await ttk.transfer(accounts[idx], value, { from: tokenPool });
      await ttk.approve(staking.address, -1, { from: accounts[idx] });
      let tx = await staking.delegate(value, nodeAddr, {
        from: accounts[idx]
      });
      truffleAssert.eventEmitted(tx, "DelegateTo", ev => {
        return ev.sender === accounts[idx];
      });
    }

    let apr = await staking.getCurrentAPR();
    let advancement = 86400 * 365; // 365 Days
    await time.increase(advancement);

    await staking.nodeClaimReward(nodeAddr, { from: nodeStakingAddr });
    let balance = await ttk.balanceOf(nodeStakingAddr);
    nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
    assert.equal(
      nodeBalance,
      76000,
      "After 1 year, node balance should be 76000 "
    );
    let delegatorBalance = 0;
    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await staking.delegatorClaimReward(nodeAddr, {
        from: accounts[idx]
      });
      let balance = await ttk.balanceOf(accounts[idx]);
      delegatorBalance = Math.round(balance.valueOf() / 1000000000000000000);
      assert.equal(
        delegatorBalance,
        36000,
        "After 1 year, delegator balance should be 36000 "
      );
    }
    const options = {
      filter: { sender: accounts[2] },
      fromBlock: 0,
      toBlock: "latest"
    };

    const eventList = await staking.getPastEvents("DelegateTo", options);
    assert.equal(eventList.length, 1, "");
  });
  it("test delegatorClaimReward - node only runs 73 days during a year", async () => {
    let stakedTokenPerNode = 50000;
    let proxyAddr = accounts[11];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodeStakingAddr = accounts[1];
    let nodeAddr = accounts[1];
    let delegater = 9;

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));
    await ttk.transfer(nodeStakingAddr, value, { from: tokenPool });
    await ttk.approve(staking.address, -1, { from: nodeStakingAddr });
    await staking.newNode(nodeAddr, value, 0, 10, "test", {
      from: nodeStakingAddr
    });

    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await ttk.transfer(accounts[idx], value, { from: tokenPool });
      await ttk.approve(staking.address, -1, { from: accounts[idx] });
      let tx = await staking.delegate(value, nodeAddr, {
        from: accounts[idx]
      });
    }
    let apr = await staking.getCurrentAPR();

    await staking.nodeStart(nodeAddr, {
      from: proxyAddr
    });
    let advancement = 86400 * 20; // 365 Days
    await time.increase(advancement);

    await staking.nodeStop(nodeAddr, {
      from: proxyAddr
    });
    advancement = 86400 * 100; // 365 Days
    await time.increase(advancement);

    await staking.nodeStart(nodeAddr, {
      from: proxyAddr
    });
    advancement = 86400 * 53; // 365 Days
    await time.increase(advancement);

    await staking.nodeStop(nodeAddr, {
      from: proxyAddr
    });
    advancement = 86400 * 192; // 365 Days
    await time.increase(advancement);

    await staking.nodeClaimReward(nodeAddr, { from: nodeStakingAddr });
    let balance = await ttk.balanceOf(nodeStakingAddr);
    nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
    assert.equal(
      nodeBalance,
      15200,
      "After 1 year, node balance should be 15200 "
    );
    let delegatorBalance = 0;
    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await staking.delegatorClaimReward(nodeAddr, {
        from: accounts[idx]
      });
      let balance = await ttk.balanceOf(accounts[idx]);
      delegatorBalance = Math.round(balance.valueOf() / 1000000000000000000);
      assert.equal(
        delegatorBalance,
        7200,
        "After 1 year, delegator balance should be 7200 "
      );
    }
  });
  it("test nodeUnregister - node only runs 73 days during a year", async () => {
    let stakedTokenPerNode = 50000;
    let proxyAddr = accounts[11];
    let stakingRewardsVault = accounts[0];
    let tokenPool = accounts[0];
    let nodeStakingAddr = accounts[1];
    let nodeAddr = accounts[1];
    let delegater = 9;

    let ttk = await Ttk.new();
    let bridge = await Bridge.new();
    await bridge.setProxyAddress(proxyAddr);
    let staking = await Staking.new(
      ttk.address,
      ttk.address,
      stakingRewardsVault,
      bridge.address
    );
    await ttk.approve(staking.address, -1, { from: stakingRewardsVault });

    let decimals = web3.utils.toBN(18);
    let amount = web3.utils.toBN(stakedTokenPerNode);
    let value = amount.mul(web3.utils.toBN(10).pow(decimals));
    await ttk.transfer(nodeStakingAddr, value, { from: tokenPool });
    await ttk.approve(staking.address, -1, { from: nodeStakingAddr });
    await staking.newNode(nodeAddr, value, 0, 10, "test", {
      from: nodeStakingAddr
    });
    let nodeAddrs = await staking.getNodeAddrs();
    assert.equal(
      nodeAddrs.length,
      1,
      "After newNode, length of nodeAddrs should be 1 "
    );

    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await ttk.transfer(accounts[idx], value, { from: tokenPool });
      await ttk.approve(staking.address, -1, { from: accounts[idx] });
      await staking.delegate(value, nodeAddr, {
        from: accounts[idx]
      });
    }

    let apr = await staking.getCurrentAPR();
    await staking.nodeStart(nodeAddr, {
      from: proxyAddr
    });

    let advancement = 86400 * 73; // 365 Days
    await time.increase(advancement);
    await staking.nodeUnregister(nodeAddr, {
      from: nodeStakingAddr
    });

    advancement = 86400 * 100; // 365 Days
    await time.increase(advancement);

    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;
      await staking.delegatorUnbond(value, nodeAddr, {
        from: accounts[idx]
      });
    }

    dvancement = 86400 * 7; // 365 Days
    await time.increase(advancement);

    let delegatorBalance = 0;
    for (var i = 1; i <= delegater; i++) {
      let idx = i + 1;

      await staking.delegatorClaimReward(nodeAddr, {
        from: accounts[idx]
      });
      let balance = await ttk.balanceOf(accounts[idx]);
      delegatorBalance = Math.round(balance.valueOf() / 1000000000000000000);
      assert.equal(
        delegatorBalance,
        7200,
        "After 1 year, delegator balance should be 7200 "
      );

      await staking.delegatorWithdraw(nodeAddr, {
        from: accounts[idx]
      });
      balance = await ttk.balanceOf(accounts[idx]);
      delegatorBalance = Math.round(balance.valueOf() / 1000000000000000000);
      assert.equal(
        delegatorBalance,
        57200,
        "After 1 year, delegator balance should be 57200 "
      );
    }

    await staking.nodeClaimReward(nodeAddr, { from: nodeStakingAddr });
    let balance = await ttk.balanceOf(nodeStakingAddr);
    nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
    assert.equal(
      nodeBalance,
      15200,
      "After 1 year, node balance should be 15200 "
    );
    await staking.nodeWithdraw(nodeAddr, { from: nodeStakingAddr });
    balance = await ttk.balanceOf(nodeStakingAddr);
    nodeBalance = Math.round(balance.valueOf() / 1000000000000000000);
    assert.equal(
      nodeBalance,
      65200,
      "After 1 year, node balance should be 65200 "
    );
    nodeAddrs = await staking.getNodeAddrs();
    assert.equal(
      nodeAddrs.length,
      0,
      "After unregister, length of nodeAddrs should be 0 "
    );
  });
});
