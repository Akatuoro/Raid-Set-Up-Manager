local addon, ns = ...

local groupassignment = {};	-- groupassignment[subgroup] = {player1, player2, player3, player4, player5}  where playerx is a name
local maxgroups = ns.maxgroups;
local maxmembers = ns.maxmembers;

ns.gm = {}


function ns.gm.Clear()
	for i=1,maxgroups,1 do
		groupassignment[i] = {};
	end
	ns.mm.Clear()
end


-- unused?
function ns.gm.GetGroupByName(name)
	if name then
		if groupassignment then
			for group=1,maxgroups,1 do
				if groupassignment[group] then
					for member=1,maxmembers,1 do
						if groupassignment[group][member] == name then
							return group, member;
						end
					end
				end
			end
		end
	end
	return nil,nil;
end

function ns.gm.SortByName(group)
	if group and groupassignment[group] then
		table.sort(groupassignment[group])
	end
end


local function FindSpot(rear)
	-- searches a free sport for the member. if rear is true then search from the rear
	local start, finish, step;
	if rear then
		start = maxgroups;
		finish = 1;
		step = -1;
	else
		start = 1;
		finish = maxgroups;
		step = 1;
	end
	
	for group=start,finish,step do
		if groupassignment[group] then
			if not groupassignment[group][maxmembers] then
				return group;
			end
		end
	end
end


-- add virtual member to virtual group. fails if group full
function ns.gm.Add(name, group, rear)
	if not group then
		group = FindSpot(rear)
	end

	for i=1,maxmembers,1 do
		if groupassignment[group][i] == nil then
			groupassignment[group][i] = name;
			return true;
		end
	end
	return false;
end

-- remove virtual member from virtual group
function ns.gm.Remove(group, member)
	for i=member,maxmembers-1,1 do
		groupassignment[group][i] = groupassignment[group][i+1];
	end
	groupassignment[group][maxmembers] = nil;
end

-- swap virtual members in different groups
function ns.gm.Swap(sourcegroup, sourcemember, targetgroup, targetmember)
	if sourcegroup == targetgroup then
		return;
	end
	local tempname = groupassignment[sourcegroup][sourcemember];
	groupassignment[sourcegroup][sourcemember] = groupassignment[targetgroup][targetmember];
	groupassignment[targetgroup][targetmember] = tempname;
end

-- try to move virtual member to new group. fails if targetgroup is full
function ns.gm.Move(sourcegroup, sourcemember, targetgroup)
	if sourcegroup == targetgroup then
		return true;
	end
	if ns.gm.Add(groupassignment[sourcegroup][sourcemember], targetgroup) then
		ns.gm.Remove(sourcegroup, sourcemember);
		return true;
	end
	return false;
end

function ns.gm.Member(group, member)
	if groupassignment[group] and groupassignment[group][member] then
		return groupassignment[group][member];
	end
	return nil;
end

function ns.gm.MemberList()
	list = {}
	for i=1,maxgroups,1 do
		if groupassignment[i] then
			for j=1,maxmembers,1 do
				if groupassignment[i][j] then
					list[groupassignment[i][j]] = {group = i, member = j}
				end
			end
		end
	end
	return list
end


function ns.gm.Copy(source, target)
	if not source or not target then
		return;
	end
	for group=1,maxgroups,1 do
		target[group] = {};
		for member=1,maxmembers,1 do
			target[group][member] = source[group][member]
			if source[group][member] then
				ns.mm.Create(source[group][member])
			end
		end
	end
end

function ns.gm.CopyCurrent(target)
	ns.gm.Copy(groupassignment, target)
end

function ns.gm.Set(assignment)
	ns.mm.Clear()
	if assignment then
		ns.gm.Copy(assignment, groupassignment)
	end
	ns.mm.SyncSpecs()
end

function ns.gm.Sort(name)
	ns.mm.SyncSpecs()
	groupassignment = ns.autosort.func[name](groupassignment)
end