module system

pub struct ZosStatistics {
pub mut:
	cru u64
	sru u64
	hru u64
	mru u64
	ipv4u u64
}

pub struct ZosStatisticsGetResponse {
pub mut:
	total ZosStatistics
	used ZosStatistics
}
