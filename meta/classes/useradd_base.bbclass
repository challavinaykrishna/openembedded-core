#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

# This bbclass provides basic functionality for user/group settings.
# This bbclass is intended to be inherited by useradd.bbclass and
# extrausers.bbclass.

# The following functions basically have similar logic.
# *) Perform necessary checks before invoking the actual command
# *) Invoke the actual command with flock
# *) Error out if an error occurs.

# Note that before invoking these functions, make sure the global variable
# PSEUDO is set up correctly.

perform_groupadd () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing groupadd with [$opts]"
	local groupname=`echo "$opts" | awk '{ print $NF }'`
	local group_exists="`grep "^$groupname:" $rootdir/etc/group || true`"
	if test "x$group_exists" = "x"; then
		eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupadd \$opts\" || true
		group_exists="`grep "^$groupname:" $rootdir/etc/group || true`"
		if test "x$group_exists" = "x"; then
			bbfatal "${PN}: groupadd command did not succeed."
		fi
	else
		bbnote "${PN}: group $groupname already exists, not re-creating it"
	fi
}

perform_useradd () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing useradd with [$opts]"
	local username=`echo "$opts" | awk '{ print $NF }'`
	local user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
	
	if test "x$user_exists" = "x"; then
		# Extract supplementary groups from -G option for separate handling
		local supplementary_groups=""
		local useradd_opts="$opts"
		
		# Check if -G option is present
		if echo "$opts" | grep -q "\-G "; then
			supplementary_groups=`echo "$opts" | sed -n 's/.*-G \([^ ]*\).*/\1/p'`
			# Remove -G option and its argument from useradd command
			useradd_opts=`echo "$opts" | sed 's/-G [^ ]* //g'`
		fi
		
		# Create user without supplementary groups first
		eval flock -x $rootdir${sysconfdir} -c  \"$PSEUDO useradd \$useradd_opts\" || true
		user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
		if test "x$user_exists" = "x"; then
			bbfatal "${PN}: useradd command did not succeed."
		fi
		
		# Add user to supplementary groups using perform_groupmems
		if test "x$supplementary_groups" != "x"; then
			local IFS=','
			for group in $supplementary_groups; do
				if test "x$group" != "x"; then
					bbnote "${PN}: Adding $username to supplementary group $group using groupmems"
					perform_groupmems "$rootdir" "-g $group -a $username"
				fi
			done
		fi
	else
		bbnote "${PN}: user $username already exists, not re-creating it"
	fi
}

perform_groupmems () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing groupmems with [$opts]"
	local groupname=`echo "$opts" | awk '{ for (i = 1; i < NF; i++) if ($i == "-g" || $i == "--group") print $(i+1) }'`
	
	# Check if this is an add (-a) or delete (-d) operation
	local is_add=`echo "$opts" | grep -E "\-a|\-\-add" || true`
	local is_delete=`echo "$opts" | grep -E "\-d|\-\-delete" || true`
	
	if test "x$is_add" != "x"; then
		# Adding user to group
		local username=`echo "$opts" | awk '{ for (i = 1; i < NF; i++) if ($i == "-a" || $i == "--add") print $(i+1) }'`
		bbnote "${PN}: Running groupmems command to add user $username to group $groupname"
		local mem_exists="`grep "^$groupname:[^:]*:[^:]*:\([^,]*,\)*$username\(,[^,]*\)*$" $rootdir/etc/group || true`"
		if test "x$mem_exists" = "x"; then
			eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupmems \$opts\" || true
			mem_exists="`grep "^$groupname:[^:]*:[^:]*:\([^,]*,\)*$username\(,[^,]*\)*$" $rootdir/etc/group || true`"
			if test "x$mem_exists" = "x"; then
				bbfatal "${PN}: groupmems add command did not succeed."
			fi
		else
			# During upgrades, group membership may be removed by postrm, so always try to re-add
			eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupmems \$opts\" || true
			bbnote "${PN}: Re-added user $username to group $groupname"
		fi
	elif test "x$is_delete" != "x"; then
		# Removing user from group
		local username=`echo "$opts" | awk '{ for (i = 1; i < NF; i++) if ($i == "-d" || $i == "--delete") print $(i+1) }'`
		bbnote "${PN}: Running groupmems command to remove user $username from group $groupname"
		local mem_exists="`grep "^$groupname:[^:]*:[^:]*:\([^,]*,\)*$username\(,[^,]*\)*$" $rootdir/etc/group || true`"
		if test "x$mem_exists" != "x"; then
			eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupmems \$opts\" || true
			mem_exists="`grep "^$groupname:[^:]*:[^:]*:\([^,]*,\)*$username\(,[^,]*\)*$" $rootdir/etc/group || true`"
			if test "x$mem_exists" != "x"; then
				bbwarn "${PN}: groupmems delete command did not succeed."
			fi
		else
			bbnote "${PN}: group $groupname doesn't contain $username, not removing it"
		fi
	else
		bbwarn "${PN}: groupmems command missing add (-a) or delete (-d) operation"
	fi
}

perform_groupdel () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing groupdel with [$opts]"
	local groupname=`echo "$opts" | awk '{ print $NF }'`
	local group_exists="`grep "^$groupname:" $rootdir/etc/group || true`"

	if test "x$group_exists" != "x"; then
		local awk_input='BEGIN {FS=":"}; $1=="'$groupname'" { print $3 }'
		local groupid=`echo "$awk_input" | awk -f- $rootdir/etc/group`
		local awk_check_users='BEGIN {FS=":"}; $4=="'$groupid'" {print $1}'
		local other_users=`echo "$awk_check_users" | awk -f- $rootdir/etc/passwd`

		if test "x$other_users" = "x"; then
			eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupdel \$opts\" || true
			group_exists="`grep "^$groupname:" $rootdir/etc/group || true`"
			if test "x$group_exists" != "x"; then
				bbfatal "${PN}: groupdel command did not succeed."
			fi
		else
			bbnote "${PN}: '$groupname' is primary group for users '$other_users', not removing it"
		fi
	else
		bbnote "${PN}: group $groupname doesn't exist, not removing it"
	fi
}

perform_userdel () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing userdel with [$opts]"
	local username=`echo "$opts" | awk '{ print $NF }'`
	local user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
	if test "x$user_exists" != "x"; then
		eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO userdel \$opts\" || true
		user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
		if test "x$user_exists" != "x"; then
			bbfatal "${PN}: userdel command did not succeed."
		fi
	else
		bbnote "${PN}: user $username doesn't exist, not removing it"
	fi
}

perform_groupmod () {
	# Other than the return value of groupmod, there's no simple way to judge whether the command
	# succeeds, so we disable -e option temporarily
	set +e
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing groupmod with [$opts]"
	local groupname=`echo "$opts" | awk '{ print $NF }'`
	local group_exists="`grep "^$groupname:" $rootdir/etc/group || true`"
	if test "x$group_exists" != "x"; then
		eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO groupmod \$opts\"
		if test $? != 0; then
			bbwarn "${PN}: groupmod command did not succeed."
		fi
	else
		bbwarn "${PN}: group $groupname doesn't exist, unable to modify it"
	fi
	set -e
}

perform_usermod () {
	# Same reason with groupmod, temporarily disable -e option
	set +e
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing usermod with [$opts]"
	local username=`echo "$opts" | awk '{ print $NF }'`
	local user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
	if test "x$user_exists" != "x"; then
		eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO usermod \$opts\"
		if test $? != 0; then
			bbfatal "${PN}: usermod command did not succeed."
		fi
	else
		bbwarn "${PN}: user $username doesn't exist, unable to modify it"
	fi
	set -e
}

perform_passwd_expire () {
	local rootdir="$1"
	local opts="$2"
	bbnote "${PN}: Performing equivalent of passwd --expire with [$opts]"
	# Directly set sp_lstchg to 0 without using the passwd command: Only root can do that
	local username=`echo "$opts" | awk '{ print $NF }'`
	local user_exists="`grep "^$username:" $rootdir/etc/passwd || true`"
	if test "x$user_exists" != "x"; then
		eval flock -x $rootdir${sysconfdir} -c \"$PSEUDO sed --follow-symlinks -i \''s/^\('$username':[^:]*\):[^:]*:/\1:0:/'\' $rootdir/etc/shadow \" || true
		local passwd_lastchanged="`grep "^$username:" $rootdir/etc/shadow | cut -d: -f3`"
		if test "x$passwd_lastchanged" != "x0"; then
			bbfatal "${PN}: passwd --expire operation did not succeed."
		fi
	else
		bbnote "${PN}: user $username doesn't exist, not expiring its password"
	fi
}
