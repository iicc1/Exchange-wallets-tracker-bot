-- config.lua https://github.com/iicc1/Exchange-wallets-tracker-bot
-- Contribute adding more exchange wallets in the same way they are placed here
-- Wallets names are taken from etherscan except the "Unnamed" ones

local _M = {}

_M.binance = {
    BinanceWallet = "0x3f5ce5fbfe3e9af3971dd833d26ba9b5c936f0be",
    BinanceWallet_1 = "0xd551234ae421e3bcba99a0da6d736074f22192ff",
    BinanceWallet_2 = "0x564286362092D8e7936f0549571a803B203aAceD",
    BinanceUnnamed = "0x0681d8db095565fe8a346fa0277bffde9c0edbbf",
}

_M.bittrex = {
    Bittrex = "0xfbb1b73c4f0bda4f67dca266ce6ef42f520fbb98",
    Bittrex_2 = "0xe94b04a0fed112f3664e45adb2b8915693dd5ff3",
}

_M.bitfinex = {
    Bitfinex = "0x7180EB39A6264938FDB3EfFD7341C4727c382153",
    Bitfinex_1 = "0xcAfB10eE663f465f9d10588AC44eD20eD608C11e",
    Bitfinex_Wallet1 = "0x1151314c646Ce4E0eFD76d1aF4760aE66a9Fe30F",
    Bitfinex_Wallet2 = "0x7727E5113D1d161373623e5f49FD568B4F543a9E",
    Bitfinex_Wallet3 = "0x4fdd5eb2fb260149a3903859043e962ab89d8ed4",
    Bitfinex_Wallet4 = "0x876EabF441B2EE5B5b0554Fd502a8E0600950cFa",
}

_M.kraken = {
	Kraken_1 = "0x2910543Af39abA0Cd09dBb2D50200b3E800A63D2",
	Kraken_2 = "0x0A869d79a7052C7f1b55a8EbAbbEa3420F0D1E13",
	Kraken_3 = "0x0a869d79a7052c7f1b55a8ebabbea3420f0d1e13",
    Kraken_3 = "0xe853c56864a2ebe4576a807d26fdc4a0ada51919",
    Kraken_4 = "0x267be1c1d684f78cb4f6a176c4911b741e4ffdc0",
}

_M.kucoin = {
    KucoinUnnamed = "0x2b5634c42055806a59e9107ed44d43c426e58258",
}

_M.poloniex = {
    Poloniex_ColdWallet = "0xb794F5eA0ba39494cE839613fffBA74279579268",
    Poloniex_Wallet = "0x32Be343B94f860124dC4fEe278FDCBD38C102D88",
    Poloniex  = "0xaB11204cfEacCFfa63C2D23AeF2Ea9aCCDB0a0D5",
    Poloniex_2 = "0x209c4784AB1E8183Cf58cA33cb740efbF3FC18EF",
}

_M.huobi = {
    HuobiUnnamed = "0x5c985e89dde482efe97ea9f1950ad149eb73829b",
}

_M.liqui = {
    liqui_io = "0x8271B2E8CBe29396e9563229030c89679B9470db",
    liqui_io_Erc20 = "0x5E575279bf9f4acf0A130c186861454247394C06",
}

return _M