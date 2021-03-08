const StringUtilsMock = artifacts.require("StringUtilsMock");

contract("StringUtils test", async() => {
    let stringUtils;
    before(async() => {
        stringUtils = await StringUtilsMock.new();
    })

    it("Test transfer byte to uint", async() => {
        let num = await stringUtils.createByte.call();
        let numOverflow = web3.utils.toHex('A');
        let result = await stringUtils.byte2Uint.call(num);
        let resultOverflow = await stringUtils.byte2Uint.call(numOverflow);
        assert.equal(result, 6, "transfer byte to uint");
        assert.equal(resultOverflow, 10, "transfer overflow");
    })

    it("Test transfer hexByte to uint", async() => {
        let num = await stringUtils.createByte.call();
        let char = web3.utils.toHex('F');
        let charOverflow = web3.utils.toHex('G');
        let result = await stringUtils.byte2Uint.call(num);
        let charResult = await stringUtils.hexByte2Uint.call(char);
        let charResultOverflow = await stringUtils.hexByte2Uint.call(charOverflow);
        assert.equal(result, 6, "transfer hex byte to uint");
        assert.equal(charResult, 15, "transfer hexByte to uint");
        assert.equal(charResultOverflow, 16, "transfer hexByte to uint");
    })

    it("Test decimalStr to uint", async() => {
        let stringDecimal = "846686978";
        let stringChar = "678Aaaa";
        let stringOverflow ="11579208923731619542357098500868790785326998466564056403945758400791312963993555555";
        let stringDecimalResult = await stringUtils.str2Uint.call(stringDecimal);
        let stringCharResult = await stringUtils.str2Uint.call(stringChar);
        let stringDecimalOverflow = await stringUtils.str2Uint.call(stringOverflow);
        const UINT256MAX = await stringUtils.returnUINT256MAX.call();
        assert.equal(stringDecimalResult, 846686978, "transfer a decimal string to uint" );
        assert.equal(stringCharResult, 678,"transefer a char string to uint");
        assert.equal(stringDecimalOverflow.toString(10), UINT256MAX.toString(10), "Overflow:transfer a decimal string to uint");
    })

    it("Test hexStr to uint", async() => {
        const UINT256MAX = await stringUtils.returnUINT256MAX.call();
        let hexString0 =  "d19Ab";
        let hexString1 = "0xd19Ab";
        let hexString2 = "0Xd19Ab";
        let hexStringInvalid = "0x";
        let hexStringOverflow = "0x11579208923A73161b9542357098500d86879078534545455454545454544545554444adadaadadaddad";
        let hexStringResult0 = await stringUtils.hexStr2Uint.call(hexString0);
        let hexStringResult1 = await stringUtils.hexStr2Uint.call(hexString1);
        let hexStringResult2 = await stringUtils.hexStr2Uint.call(hexString2);
        let hexStringInvalidResult = await stringUtils.hexStr2Uint.call(hexStringInvalid);
        let hexStringResultOverflow = await stringUtils.hexStr2Uint.call(hexStringOverflow);
        assert.equal(hexStringResult0,858539,"transfer a hex string to uint");
        assert.equal(hexStringResult1,858539,"transfer a hex string to uint");
        assert.equal(hexStringResult2,858539,"transfer a hex string to uint");
        assert.equal(hexStringInvalidResult,0,"transfer a hex string to uint");
        assert.equal(hexStringResultOverflow.toString(10), UINT256MAX.toString(10), "transfer a hex string to uint");
    })

    it("Test 20-byte hex string to address", async() => {
        let hexString = "0x0e7ad63d2a305a7b9f46541c386aafbd2af6b263";
        let hexStringResult = await stringUtils.str2Addr.call(hexString);
        assert.equal(hexStringResult, 0x0e7ad63d2a305a7b9f46541c386aafbd2af6b263, "transfer 20-byte hex string to uint");
    })

    it("Test address to string", async() => {
        let hexAddr = "0x0e7ad63d2a305a7b9f46541c386aafbd2af6b263";
        let hexAddrResult = await stringUtils.addr2Str.call(hexAddr);
        assert.equal(hexAddrResult, "0x0e7ad63d2a305a7b9f46541c386aafbd2af6b263", "transfer address to string");
    })

    it("Test uint to hex string", async() => {
        let uintZero = 0;
        let uintValid = 12;
        let uintZeroResult = await stringUtils.uint2HexStr.call(uintZero);
        let uintValidResult = await stringUtils.uint2HexStr.call(uintValid);
        assert.equal(uintZeroResult, 0, "transfer uint to hex string");
        assert.equal(uintValidResult, 'C', "transfer uint to hex string");
    })

    it("Test uint to string", async() => {
        let uintZero = 0;
        let uintValid = 12;
        let uintZeroResult = await stringUtils.uint2Str.call(uintZero);
        let uintValidResult = await stringUtils.uint2Str.call(uintValid);
        assert.equal(uintZeroResult, "0", "transfer uint to hex string");
        assert.equal(uintValidResult, "12", "transfer uint to hex string");
    })

    it("Test strConcat and byteConcat", async() => {
        let aa = "Hello ";
        let bb = "world!";
        let result = await stringUtils.strConcat.call(aa, bb);
        assert.equal(result, "Hello world!", "string concat");
    })

    it("Test strCompare and byteCompare", async() => {
        let aa = "abd";
        let bb = "abcde";
        let result = await stringUtils.strCompare.call(aa,bb);
        assert.equal(result,1,"string compare");
    })

    it("Test strEqual and byteEqual", async() => {
        let aa = "dosnetwork";
        let bb = "dosnetwork";
        let result = await stringUtils.strEqual.call(aa,bb);
        assert.equal(result,true,"string equal");
    })

    it("Test indexOf(string) and indexOf(bytes)", async() => {
        let haystack0 = "123";
        let needle0 = "";
        let haystack1 = "";
        let needle1 = "45";
        let haystack2 = "123";
        let needle2 = "1234";
        let haystack3 = "123.45";
        let needle3 = ".";
        let result0 = await stringUtils.indexOf(haystack0,needle0);
        let result1 = await stringUtils.indexOf(haystack1,needle1);
        let result2 = await stringUtils.indexOf(haystack2,needle2);
        let result3 = await stringUtils.indexOf(haystack3,needle3);
        assert.equal(result0,0,"get index");
        assert.equal(result1,haystack1.length,"get index");
        assert.equal(result2,haystack2.length,"get index");
        assert.equal(result3,3,"get index");
    })

    it("Test subStr(string,uint,uint) and subStr(bytes,uint,uint)", async() => {
        let a = "1234567890";
        let start = 2;
        let len = 5;
        let result = await stringUtils.subStr.call(a, start, len);
        assert.equal(result, "34567", "get substring");
    })

    it("Test subStr(string,uint) and subStr(bytes,uint)", async() => {
        let num = "123.4567";
        let result = await stringUtils.subStr1.call(num, 4);
        assert.equal(result, "4567", "get substring");
    })
})
