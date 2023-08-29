interface IWithdrawalAddress {
	function withdrawalAddress()
		external
		view
		responsible
		returns (address addr);
}
