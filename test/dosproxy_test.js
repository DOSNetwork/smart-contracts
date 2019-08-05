const DOSProxyMock = artifacts.require("DOSProxyMock");
const truffleAssert = require('truffle-assertions');
contract("DOSProxy Test", async accounts => {
	it("test unregister node from pendingNodeList", async () => {
		let dosproxy = await DOSProxyMock.new()
		let tx = await dosproxy.registerNewNode({ from: accounts[0] });
		let tx2 = await dosproxy.registerNewNode({ from: accounts[1] });
		truffleAssert.eventEmitted(tx, 'LogRegisteredNewPendingNode', (ev) => {
            return ev.node === accounts[0];
        });
		truffleAssert.eventEmitted(tx2, 'LogInsufficientPendingNode', (ev) => {
			return ev.numPendingNodes.toNumber() === web3.utils.toBN(2).toNumber();
        });
		var node = await dosproxy.pendingNodeList.call(accounts[0]);
		assert.equal(node, accounts[1],
					"After register, account 0 should point to account 1");
					
		let tx3 = await dosproxy.unregisterNode({ from: accounts[0] });
		var node = await dosproxy.pendingNodeList.call(accounts[0]);
		assert.equal(node, 0,
					"After register, account 0 should not be in the list");		
		truffleAssert.eventEmitted(tx3, 'LogUnRegisteredNewPendingNode', (ev) => {
			return ev.node === accounts[0];
        });
	});
	it("test unregister node from pendingGroup", () => {
    let dosproxy;
	let group1
	let group2
	let group3
	let groupid1;
	let groupid2;
	let groupid3;
	let group1Mem1;
	let group1Mem2;
	let group1Mem3;
	let group2Mem1;
	let group2Mem2;
	let group2Mem3;	
	let group3Mem1;
	let group3Mem2;
	let group3Mem3;	
	let numPendingNodes
	let numPendingGroups
	let workingGroupIdsLength
	let expiredWorkingGroupIdsLength
	let tx
	let tx2
	let tx3
    return DOSProxyMock.new()
		.then(async (instance) => {
        		dosproxy = instance;
			await dosproxy.registerNewNode({ from: accounts[0] });
			await dosproxy.registerNewNode({ from: accounts[1] });
			await dosproxy.registerNewNode({ from: accounts[2] });
			await dosproxy.registerNewNode({ from: accounts[3] });
			await dosproxy.registerNewNode({ from: accounts[4] });
			await dosproxy.registerNewNode({ from: accounts[5] });
			await dosproxy.registerNewNode({ from: accounts[6] });
			await dosproxy.registerNewNode({ from: accounts[7] });
			tx = await dosproxy.registerNewNode({ from: accounts[8] });
			await dosproxy.registerNewNode({ from: accounts[9] });
			
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()

			truffleAssert.eventNotEmitted(tx, 'LogError');
			assert.equal(numPendingNodes.toNumber(), 10,
					"After register, numPendingNodes should be 10");
			assert.equal(numPendingGroups.toNumber(), 0,
					"After register, numPendingGroups should be 0");
			assert.equal(workingGroupIdsLength.toNumber(), 0,
					"Before signalBootstrap, length of workingGroupIds should be 0");
			assert.equal(expiredWorkingGroupIdsLength.toNumber(), 0,
					"Before signalBootstrap, length of expiredWorkingGroupIds should be 0");
			return numPendingNodes;
		})
		.then(async (numPendingNodes) => {
			tx = await dosproxy.signalBootstrap(1,{ from: accounts[0] });
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()

			assert.equal(numPendingNodes.toNumber(), 1,
					"After signalBootstrap, numPendingNodes should be 1");
			assert.equal(numPendingGroups.toNumber(), 3,
					"After signalBootstrap, numPendingGroups should be 3");
			assert.equal(workingGroupIdsLength.toNumber(), 0,
					"After signalBootstrap, workingGroupIds length should be 0");
			assert.equal(expiredWorkingGroupIdsLength.toNumber(), 0,
					"After signalBootstrap, length of expiredWorkingGroupIds should be 0");
			return tx;
		})
		.then(async (res) => {
			tx = await dosproxy.getPastEvents( 'LogGrouping', { fromBlock: 0, toBlock: 'latest' } )
			assert.equal(tx.length, 3,
					"After signalBootstrap, length of LogGrouping should be 3");
			groupid1 = tx[0].returnValues.groupId;
			group1Mem1 = tx[0].returnValues.nodeId[0];
			group1Mem2 = tx[0].returnValues.nodeId[1];
			group1Mem3 = tx[0].returnValues.nodeId[2];
			groupid2 = tx[1].returnValues.groupId;
			group2Mem1 = tx[1].returnValues.nodeId[0];
			group2Mem2 = tx[1].returnValues.nodeId[1];
			group2Mem3 = tx[1].returnValues.nodeId[2];
			groupid3 = tx[2].returnValues.groupId;
			group3Mem1 = tx[2].returnValues.nodeId[0];
			group3Mem2 = tx[2].returnValues.nodeId[1];
			group3Mem3 = tx[2].returnValues.nodeId[2];	
			return tx;
		})
		.then(async (res) => {
			await dosproxy.unregisterNode({ from: group1Mem1 });
			let tx = await dosproxy.unregisterNode({ from: group2Mem2 });
			return tx
		})
		.then(async (res) => {
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()
			console.log("numPendingNodes : ",numPendingNodes.toNumber())
			console.log("numPendingGroups : ",numPendingGroups.toNumber())
			console.log("workingGroupIdsLength : ",workingGroupIdsLength.toNumber())
			console.log("expiredWorkingGroupIdsLength : ",expiredWorkingGroupIdsLength.toNumber())
		});	
	});
	it("test unregister node from workingGroup", () => {
    let dosproxy;
	let group1
	let group2
	let group3
	let groupid1;
	let groupid2;
	let groupid3;
	let group1Mem1;
	let group1Mem2;
	let group1Mem3;
	let group2Mem1;
	let group2Mem2;
	let group2Mem3;	
	let group3Mem1;
	let group3Mem2;
	let group3Mem3;	
	let numPendingNodes
	let numPendingGroups
	let workingGroupIdsLength
	let expiredWorkingGroupIdsLength
	let tx
	let tx2
	let tx3
    return DOSProxyMock.new()
		.then(async (instance) => {
        		dosproxy = instance;
			await dosproxy.registerNewNode({ from: accounts[0] });
			await dosproxy.registerNewNode({ from: accounts[1] });
			await dosproxy.registerNewNode({ from: accounts[2] });
			await dosproxy.registerNewNode({ from: accounts[3] });
			await dosproxy.registerNewNode({ from: accounts[4] });
			await dosproxy.registerNewNode({ from: accounts[5] });
			await dosproxy.registerNewNode({ from: accounts[6] });
			await dosproxy.registerNewNode({ from: accounts[7] });
			tx = await dosproxy.registerNewNode({ from: accounts[8] });
			await dosproxy.registerNewNode({ from: accounts[9] });
			
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()

			truffleAssert.eventNotEmitted(tx, 'LogError');
			assert.equal(numPendingNodes.toNumber(), 10,
					"After register, numPendingNodes should be 10");
			assert.equal(numPendingGroups.toNumber(), 0,
					"After register, numPendingGroups should be 0");
			assert.equal(workingGroupIdsLength.toNumber(), 0,
					"Before signalBootstrap, length of workingGroupIds should be 0");
			assert.equal(expiredWorkingGroupIdsLength.toNumber(), 0,
					"Before signalBootstrap, length of expiredWorkingGroupIds should be 0");
			return numPendingNodes;
		})
		.then(async (numPendingNodes) => {
			tx = await dosproxy.signalBootstrap(1,{ from: accounts[0] });
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()

			assert.equal(numPendingNodes.toNumber(), 1,
					"After signalBootstrap, numPendingNodes should be 1");
			assert.equal(numPendingGroups.toNumber(), 3,
					"After signalBootstrap, numPendingGroups should be 3");
			assert.equal(workingGroupIdsLength.toNumber(), 0,
					"After signalBootstrap, workingGroupIds length should be 0");
			assert.equal(expiredWorkingGroupIdsLength.toNumber(), 0,
					"After signalBootstrap, length of expiredWorkingGroupIds should be 0");
			return tx;
		})
		.then(async (res) => {
			tx = await dosproxy.getPastEvents( 'LogGrouping', { fromBlock: 0, toBlock: 'latest' } )
			assert.equal(tx.length, 3,
					"After signalBootstrap, length of LogGrouping should be 3");
			groupid1 = tx[0].returnValues.groupId;
			group1Mem1 = tx[0].returnValues.nodeId[0];
			group1Mem2 = tx[0].returnValues.nodeId[1];
			group1Mem3 = tx[0].returnValues.nodeId[2];
			groupid2 = tx[1].returnValues.groupId;
			group2Mem1 = tx[1].returnValues.nodeId[0];
			group2Mem2 = tx[1].returnValues.nodeId[1];
			group2Mem3 = tx[1].returnValues.nodeId[2];
			groupid3 = tx[2].returnValues.groupId;
			group3Mem1 = tx[2].returnValues.nodeId[0];
			group3Mem2 = tx[2].returnValues.nodeId[1];
			group3Mem3 = tx[2].returnValues.nodeId[2];	
			return tx;
		})
		.then(async (res) => {
			var gpubKey1 = [];
			for(var i=0;i<4;i++){
    				gpubKey1.push(web3.utils.toBN(1));
			}
			await dosproxy.registerGroupPubKey(groupid1,gpubKey1,{ from: group1Mem1 })
			tx = await dosproxy.registerGroupPubKey(groupid1,gpubKey1,{ from: group1Mem2 })

			var gpubKey2 = [];
			for(var i=0;i<4;i++){
    				gpubKey2.push(web3.utils.toBN(2));
			}
			await dosproxy.registerGroupPubKey(groupid2,gpubKey2,{ from: group2Mem2 })
			tx2 = await dosproxy.registerGroupPubKey(groupid2,gpubKey2,{ from: group2Mem2 })

			var gpubKey3 = [];
			for(var i=0;i<4;i++){
    				gpubKey3.push(web3.utils.toBN(3));
			}
			await dosproxy.registerGroupPubKey(groupid3,gpubKey3,{ from: group3Mem1 })
			tx3 = await dosproxy.registerGroupPubKey(groupid3,gpubKey3,{ from: group3Mem2 })
	
			return tx3;
		})
		.then(async (tx3) => {
			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()
			group1 = await dosproxy.workingGroups.call(groupid1)
			group2 = await dosproxy.workingGroups.call(groupid2)
			group3 = await dosproxy.workingGroups.call(groupid3)
			console.log(group1)
			console.log(group2)
			console.log(group3)
			
			assert.equal(numPendingNodes.toNumber(), 1,
					"After registerGroupPubKey, numPendingNodes should be 1");
			assert.equal(numPendingGroups.toNumber(), 0,
					"After registerGroupPubKey, numPendingGroups should be 0");
			assert.equal(workingGroupIdsLength.toNumber(), 3,
					"After registerGroupPubKey, length of workingGroupIds should be 3");
			assert.equal(expiredWorkingGroupIdsLength.toNumber(), 0,
					"After registerGroupPubKey, length of expiredWorkingGroupIds should be 0");
			
			truffleAssert.eventNotEmitted(tx, 'LogError');
			truffleAssert.eventEmitted(tx, 'LogPublicKeyAccepted', (ev) => {
				return ev.numWorkingGroups.toNumber() === 1;
       		});
			truffleAssert.eventEmitted(tx2, 'LogPublicKeyAccepted', (ev) => {
				return ev.numWorkingGroups.toNumber() === 2;
       		});
			truffleAssert.eventEmitted(tx3, 'LogPublicKeyAccepted', (ev) => {
				return ev.numWorkingGroups.toNumber() === 3;
       		});		

			return tx3;
		})
		.then(async (res) => {
			await dosproxy.unregisterNode({ from: accounts[0] });
			await dosproxy.unregisterNode({ from: accounts[1] });
			await dosproxy.unregisterNode({ from: accounts[2] });
			await dosproxy.unregisterNode({ from: accounts[3] });
			await dosproxy.unregisterNode({ from: accounts[4] });
			await dosproxy.unregisterNode({ from: accounts[5] });
			await dosproxy.unregisterNode({ from: accounts[6] });
			await dosproxy.unregisterNode({ from: accounts[7] });
			await dosproxy.unregisterNode({ from: accounts[8] });
			let tx = await dosproxy.unregisterNode({ from: accounts[9] });
			return tx
		})
		.then(async (res) => {
			group1 = await dosproxy.workingGroups.call(groupid1)
			group2 = await dosproxy.workingGroups.call(groupid2)
			group3 = await dosproxy.workingGroups.call(groupid3)
			console.log(group1)
			console.log(group2)
			console.log(group3)

			numPendingNodes = await dosproxy.numPendingNodes.call();
			numPendingGroups = await dosproxy.numPendingGroups.call();
			workingGroupIdsLength = await dosproxy.workingGroupIdsLength.call()
			expiredWorkingGroupIdsLength = await dosproxy.expiredWorkingGroupIdsLength.call()
			console.log("numPendingNodes : ",numPendingNodes.toNumber())
			console.log("numPendingGroups : ",numPendingGroups.toNumber())
			console.log("workingGroupIdsLength : ",workingGroupIdsLength.toNumber())
			console.log("expiredWorkingGroupIdsLength : ",expiredWorkingGroupIdsLength.toNumber())
		});	
	});
})
