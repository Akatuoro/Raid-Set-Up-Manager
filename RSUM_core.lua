-- important global variables
local addon, ns = ...
ns.maxgroups = 8
ns.maxmembers = 5
RSUM_MAXGROUPS = 8;
RSUM_MAXMEMBERS = 5;

if not RSUM_Options then
	RSUM_Options = {};
end
if not RSUM_DB then
	RSUM_DB = {};
end