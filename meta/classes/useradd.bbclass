#
# Copyright OpenEmbedded Contributors
#
# SPDX-License-Identifier: MIT
#

inherit useradd_base

# base-passwd-cross provides the default passwd and group files in the
# target sysroot, and shadow -native and -sysroot provide the utilities
# and support files needed to add and modify user and group accounts
DEPENDS:append:class-target = " base-files shadow-native shadow-sysroot shadow base-passwd"
PACKAGE_WRITE_DEPS += "shadow-native"

# This preinstall function can be run in four different contexts:
#
# a) Before do_install
# b) At do_populate_sysroot_setscene when installing from sstate packages
# c) As the preinst script in the target package at do_rootfs time
# d) As the preinst script in the target package on device as a package upgrade
#
useradd_preinst () {
OPT=""
SYSROOT=""

if test "x$D" != "x"; then
	# Installing into a sysroot
	SYSROOT="$D"
	OPT="--root $D"

	# Make sure login.defs is there, this is to make debian package backend work
	# correctly while doing rootfs.
	# The problem here is that if /etc/login.defs is treated as a config file for
	# shadow package, then while performing preinsts for packages that depend on
	# shadow, there might only be /etc/login.def.dpkg-new there in root filesystem.
	if [ ! -e $D${sysconfdir}/login.defs -a -e $D${sysconfdir}/login.defs.dpkg-new ]; then
	    cp $D${sysconfdir}/login.defs.dpkg-new $D${sysconfdir}/login.defs
	fi

	# user/group lookups should match useradd/groupadd --root
	export PSEUDO_PASSWD="$SYSROOT"
fi

# If we're not doing a special SSTATE/SYSROOT install
# then set the values, otherwise use the environment
if test "x$UA_SYSROOT" = "x"; then
	# Installing onto a target
	# Add groups and users defined only for this package
	GROUPADD_PARAM="${GROUPADD_PARAM}"
	USERADD_PARAM="${USERADD_PARAM}"
	GROUPMEMS_PARAM="${GROUPMEMS_PARAM}"
	GROUPMOD_PARAM="${GROUPMOD_PARAM}"
	USERMOD_PARAM="${USERMOD_PARAM}"
	GROUPDEL_PARAM="${GROUPDEL_PARAM}"
	USERDEL_PARAM="${USERDEL_PARAM}"
fi

# Perform group additions first, since user additions may depend
# on these groups existing
if test "x`echo $GROUPADD_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running groupadd commands..."
	# Invoke multiple instances of groupadd for parameter lists
	# separated by ';'
	opts=`echo "$GROUPADD_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$GROUPADD_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_groupadd "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi 

if test "x`echo $USERADD_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running useradd commands..."
	# Invoke multiple instances of useradd for parameter lists
	# separated by ';'
	opts=`echo "$USERADD_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$USERADD_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_useradd "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi


if test "x`echo $GROUPMOD_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running groupmod commands..."
	# Invoke multiple instances of groupmod for parameter lists
	# separated by ';'
	opts=`echo "$GROUPMOD_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$GROUPMOD_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_groupmod "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi

if test "x`echo $USERMOD_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running usermod commands..."
	# Invoke multiple instances of usermod for parameter lists
	# separated by ';'
	opts=`echo "$USERMOD_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$USERMOD_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_usermod "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi

if test "x`echo $USERDEL_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running userdel commands..."
	# Invoke multiple instances of userdel for parameter lists
	# separated by ';'
	opts=`echo "$USERDEL_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$USERDEL_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_userdel "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi

if test "x`echo $GROUPDEL_PARAM | tr -d '[:space:]'`" != "x"; then
	echo "Running groupdel commands..."
	# Invoke multiple instances of groupdel for parameter lists
	# separated by ';'
	opts=`echo "$GROUPDEL_PARAM" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
	remaining=`echo "$GROUPDEL_PARAM" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	while test "x$opts" != "x"; do
		perform_groupdel "$SYSROOT" "$OPT $opts"
		if test "x$opts" = "x$remaining"; then
			break
		fi
		opts=`echo "$remaining" | cut -d ';' -f 1 | sed -e 's#[ \t]*$##'`
		remaining=`echo "$remaining" | cut -d ';' -f 2- | sed -e 's#[ \t]*$##'`
	done
fi
}

useradd_sysroot () {
	user_group_groupmems_add_sysroot user
}

groupadd_sysroot () {
	user_group_groupmems_add_sysroot group
}

groupmemsadd_sysroot () {
	user_group_groupmems_add_sysroot groupmems
}

groupmod_sysroot () {
	user_group_groupmems_add_sysroot groupmod
}

usermod_sysroot () {
	user_group_groupmems_add_sysroot usermod
}

groupdel_sysroot () {
	user_group_groupmems_add_sysroot groupdel
}

userdel_sysroot () {
	user_group_groupmems_add_sysroot userdel
}

user_group_groupmems_add_sysroot () {
	# Pseudo may (do_prepare_recipe_sysroot) or may not (do_populate_sysroot_setscene) be running 
	# at this point so we're explicit about the environment so pseudo can load if 
	# not already present.
	# PSEUDO_SYSROOT can contain references to the build architecture and COMPONENT_DIR
	# so needs the STAGING_FIXME below
	export PSEUDO="${FAKEROOTENV} ${PSEUDO_SYSROOT}${bindir_native}/pseudo"

	# Explicitly set $D since it isn't set to anything
	# before do_prepare_recipe_sysroot
	D=${STAGING_DIR_TARGET}

	# base-passwd's postinst may not have run yet in which case we'll get called later, just exit.
	# Beware that in some cases we might see the fake pseudo passwd here, in which case we also must
	# exit.
	if [ ! -f $D${sysconfdir}/passwd ] ||
			grep -q this-is-the-pseudo-passwd $D${sysconfdir}/passwd; then
		exit 0
	fi

	# It is also possible we may be in a recipe which doesn't have useradd dependencies and hence the
	# useradd/groupadd tools are unavailable. If there is no dependency, we assume we don't want to
	# create users in the sysroot
	if ! command -v useradd; then
		bbwarn "command useradd not found!"
		exit 0
	fi

	# Add groups and users defined for all recipe packages
	if test "$1" = "group"; then
		GROUPADD_PARAM="${@get_all_cmd_params(d, 'groupadd')}"
	elif test "$1" = "user"; then
		USERADD_PARAM="${@get_all_cmd_params(d, 'useradd')}"
	elif test "$1" = "groupmems"; then
		GROUPMEMS_PARAM="${@get_all_cmd_params(d, 'groupmems')}"
	elif test "$1" = "groupmod"; then
		GROUPMOD_PARAM="${@get_all_cmd_params(d, 'groupmod')}"
	elif test "$1" = "usermod"; then
		USERMOD_PARAM="${@get_all_cmd_params(d, 'usermod')}"
	elif test "$1" = "groupdel"; then
		GROUPDEL_PARAM="${@get_all_cmd_params(d, 'groupdel')}"
	elif test "$1" = "userdel"; then
		USERDEL_PARAM="${@get_all_cmd_params(d, 'userdel')}"
	elif test "x$1" = "x"; then
		bbwarn "missing type of passwd db action"
	fi

	# Tell the system to use the environment vars
	UA_SYSROOT=1

	useradd_preinst
}

# The export of PSEUDO in useradd_sysroot() above contains references to
# ${PSEUDO_SYSROOT} and ${PSEUDO_LOCALSTATEDIR}. Additionally, the logging
# shell functions use ${LOGFIFO}. These need to be handled when restoring
# postinst-useradd-${PN} from the sstate cache.
EXTRA_STAGING_FIXMES += "PSEUDO_SYSROOT PSEUDO_LOCALSTATEDIR LOGFIFO"

python useradd_sysroot_sstate () {
    for type, sort_prefix in [("group", "01"), ("user", "02"), ("groupmems", "03"), ("groupmod", "04"), ("usermod", "05"), ("userdel", "06"), ("groupdel", "07")]:
        scriptfile = None
        task = d.getVar("BB_CURRENTTASK")
        if task == "package_setscene":
            if type == "group":
                bb.build.exec_func("groupadd_sysroot", d)
            elif type == "user":
                bb.build.exec_func("useradd_sysroot", d)
            elif type == "groupmems":
                bb.build.exec_func("groupmemsadd_sysroot", d)
            elif type == "groupmod":
                bb.build.exec_func("groupmod_sysroot", d)
            elif type == "usermod":
                bb.build.exec_func("usermod_sysroot", d)
            elif type == "userdel":
                bb.build.exec_func("userdel_sysroot", d)
            elif type == "groupdel":
                bb.build.exec_func("groupdel_sysroot", d)
        elif task == "prepare_recipe_sysroot":
            # Used to update this recipe's own sysroot so the user/groups are available to do_install

            # If do_populate_sysroot is triggered and we write the file here, there would be an overlapping
            # files. See usergrouptests.UserGroupTests.test_add_task_between_p_sysroot_and_package
            scriptfile = d.expand("${RECIPE_SYSROOT}${bindir}/postinst-useradd-" + sort_prefix + type + "-${PN}-recipedebug")

            if type == "group":
                bb.build.exec_func("groupadd_sysroot", d)
            elif type == "user":
                bb.build.exec_func("useradd_sysroot", d)
            elif type == "groupmems":
                bb.build.exec_func("groupmemsadd_sysroot", d)
            elif type == "groupmod":
                bb.build.exec_func("groupmod_sysroot", d)
            elif type == "usermod":
                bb.build.exec_func("usermod_sysroot", d)
            elif type == "userdel":
                bb.build.exec_func("userdel_sysroot", d)
            elif type == "groupdel":
                bb.build.exec_func("groupdel_sysroot", d)
        elif task == "populate_sysroot":
            # Used when installed in dependent task sysroots
            scriptfile = d.expand("${SYSROOT_DESTDIR}${bindir}/postinst-useradd-" + sort_prefix + type + "-${PN}")

        if scriptfile:
            bb.utils.mkdirhier(os.path.dirname(scriptfile))
            with open(scriptfile, 'w') as script:
                script.write("#!/bin/sh -e\n")
                if type == "group":
                    bb.data.emit_func("groupadd_sysroot", script, d)
                    script.write("groupadd_sysroot\n")
                elif type == "user":
                    bb.data.emit_func("useradd_sysroot", script, d)
                    script.write("useradd_sysroot\n")
                elif type == "groupmems":
                    bb.data.emit_func("groupmemsadd_sysroot", script, d)
                    script.write("groupmemsadd_sysroot\n")
                elif type == "groupmod":
                    bb.data.emit_func("groupmod_sysroot", script, d)
                    script.write("groupmod_sysroot\n")
                elif type == "usermod":
                    bb.data.emit_func("usermod_sysroot", script, d)
                    script.write("usermod_sysroot\n")
                elif type == "userdel":
                    bb.data.emit_func("userdel_sysroot", script, d)
                    script.write("userdel_sysroot\n")
                elif type == "groupdel":
                    bb.data.emit_func("groupdel_sysroot", script, d)
                    script.write("groupdel_sysroot\n")
            os.chmod(scriptfile, 0o755)
}

do_prepare_recipe_sysroot[postfuncs] += "${SYSROOTFUNC}"
SYSROOTFUNC:class-target = "useradd_sysroot_sstate"
SYSROOTFUNC = ""

SYSROOT_PREPROCESS_FUNCS += "${SYSROOTFUNC}"

SSTATEPREINSTFUNCS:append:class-target = " useradd_sysroot_sstate"

USERADD_DEPENDS ??= ""
DEPENDS += "${USERADD_DEPENDS}"
do_package_setscene[depends] += "${USERADDSETSCENEDEPS}"
do_populate_sysroot_setscene[depends] += "${USERADDSETSCENEDEPS}"
USERADDSETSCENEDEPS:class-target = "${MLPREFIX}base-passwd:do_populate_sysroot_setscene pseudo-native:do_populate_sysroot_setscene shadow-native:do_populate_sysroot_setscene ${MLPREFIX}shadow-sysroot:do_populate_sysroot_setscene ${@' '.join(['%s:do_populate_sysroot_setscene' % pkg for pkg in d.getVar("USERADD_DEPENDS").split()])}"
USERADDSETSCENEDEPS = ""

# Recipe parse-time sanity checks
def update_useradd_after_parse(d):
    useradd_packages = d.getVar('USERADD_PACKAGES')

    if not useradd_packages:
        bb.fatal("%s inherits useradd but doesn't set USERADD_PACKAGES" % d.getVar('FILE', False))

    for pkg in useradd_packages.split():
        d.appendVarFlag("do_populate_sysroot", "vardeps", " USERADD_PARAM:%s GROUPADD_PARAM:%s GROUPMEMS_PARAM:%s GROUPMOD_PARAM:%s USERMOD_PARAM:%s GROUPDEL_PARAM:%s USERDEL_PARAM:%s" % (pkg, pkg, pkg, pkg, pkg, pkg, pkg))
        if not d.getVar('USERADD_PARAM:%s' % pkg) and not d.getVar('GROUPADD_PARAM:%s' % pkg) and not d.getVar('GROUPMEMS_PARAM:%s' % pkg) and not d.getVar('GROUPMOD_PARAM:%s' % pkg) and not d.getVar('USERMOD_PARAM:%s' % pkg) and not d.getVar('GROUPDEL_PARAM:%s' % pkg) and not d.getVar('USERDEL_PARAM:%s' % pkg):
            bb.fatal("%s inherits useradd but doesn't set USERADD_PARAM, GROUPADD_PARAM, GROUPMEMS_PARAM, GROUPMOD_PARAM, USERMOD_PARAM, GROUPDEL_PARAM or USERDEL_PARAM for package %s" % (d.getVar('FILE', False), pkg))

python __anonymous() {
    if not bb.data.inherits_class('nativesdk', d) \
        and not bb.data.inherits_class('native', d):
        update_useradd_after_parse(d)
}

# Return a single [GROUP|USER]ADD_PARAM formatted string which includes the
# [group|user]add parameters for all USERADD_PACKAGES in this recipe
def get_all_cmd_params(d, cmd_type):
    import string
    
    param_type = cmd_type.upper() + "_PARAM:%s"
    params = []

    useradd_packages = d.getVar('USERADD_PACKAGES') or ""
    for pkg in useradd_packages.split():
        param = d.getVar(param_type % pkg)
        if param:
            params.append(param.rstrip(" ;"))

    return "; ".join(params)

# Adds the preinst script into generated packages
fakeroot python populate_packages:prepend () {
    def update_useradd_package(pkg):
        bb.debug(1, 'adding user/group calls to preinst for %s' % pkg)

        """
        useradd preinst is appended here because pkg_preinst may be
        required to execute on the target. Not doing so may cause
        useradd preinst to be invoked twice, causing unwanted warnings.
        """
        preinst = d.getVar('pkg_preinst:%s' % pkg) or d.getVar('pkg_preinst')
        if not preinst:
            preinst = '#!/bin/sh\n'
        preinst += 'bbnote () {\n\techo "NOTE: $*"\n}\n'
        preinst += 'bbwarn () {\n\techo "WARNING: $*"\n}\n'
        preinst += 'bbfatal () {\n\techo "ERROR: $*"\n\texit 1\n}\n'

        # Preinst: Only groupadd and useradd (no groupmems)
        preinst += 'perform_groupadd () {\n%s}\n' % d.getVar('perform_groupadd')
        preinst += 'perform_useradd () {\n%s}\n' % d.getVar('perform_useradd')
        preinst += 'perform_groupmod () {\n%s}\n' % d.getVar('perform_groupmod')
        preinst += 'perform_usermod () {\n%s}\n' % d.getVar('perform_usermod')
        preinst += 'perform_groupdel () {\n%s}\n' % d.getVar('perform_groupdel')
        preinst += 'perform_userdel () {\n%s}\n' % d.getVar('perform_userdel')
        preinst += d.getVar('useradd_preinst')
        for rep in ["GROUPADD_PARAM", "USERADD_PARAM", "GROUPMOD_PARAM", "USERMOD_PARAM", "GROUPDEL_PARAM", "USERDEL_PARAM"]:
            val = d.getVar(rep + ":" + pkg) or ""
            preinst = preinst.replace("${" + rep + "}", val)
        d.setVar('pkg_preinst:%s' % pkg, preinst)

        # Postinst: Only groupmems (add memberships)
        postinst = d.getVar('pkg_postinst:%s' % pkg) or d.getVar('pkg_postinst')
        if not postinst:
            postinst = '#!/bin/sh\nset -e\n'
        postinst += 'bbnote () {\n\techo "NOTE: $*"\n}\n'
        postinst += 'bbwarn () {\n\techo "WARNING: $*"\n}\n'
        postinst += 'bbfatal () {\n\techo "ERROR: $*"\n\texit 1\n}\n'
        postinst += 'perform_groupmems () {\n%s}\n' % d.getVar('perform_groupmems')
        groupmems_param = d.getVar("GROUPMEMS_PARAM:" + pkg) or ""
        if groupmems_param:
            for cmd in groupmems_param.split(';'):
                if cmd.strip():
                    postinst += '\tperform_groupmems "" "%s"\n' % cmd.strip()
        d.setVar('pkg_postinst:%s' % pkg, postinst)

        # Generate postrm script for cleanup
        postrm = d.getVar('pkg_postrm:%s' % pkg) or d.getVar('pkg_postrm')
        if not postrm:
            postrm = '#!/bin/sh\nset -e\n'
        
        # Add helper functions for postrm
        postrm += 'bbnote () {\n\techo "NOTE: $*"\n}\n'
        postrm += 'bbwarn () {\n\techo "WARNING: $*"\n}\n'
        postrm += 'bbfatal () {\n\techo "ERROR: $*"\n\texit 1\n}\n'
        
        # Add perform_groupmems function
        postrm += 'perform_groupmems () {\n'
        postrm += '\tlocal rootdir="$1"\n'
        postrm += '\tlocal opts="$2"\n'
        postrm += '\tbbnote "${PN}: Performing groupmems with [$opts]"\n'
        postrm += '\tlocal groupname=`echo "$opts" | awk \'{ for (i = 1; i < NF; i++) if ($i == "-g" || $i == "--group") print $(i+1) }\'`\n'
        postrm += '\t\n'
        postrm += '\t# Check if this is an add (-a) or delete (-d) operation\n'
        postrm += '\tlocal is_add=`echo "$opts" | grep -E "\\-a|\\-\\-add" || true`\n'
        postrm += '\tlocal is_delete=`echo "$opts" | grep -E "\\-d|\\-\\-delete" || true`\n'
        postrm += '\t\n'
        postrm += '\tif test "x$is_add" != "x"; then\n'
        postrm += '\t\t# Adding user to group\n'
        postrm += '\t\tlocal username=`echo "$opts" | awk \'{ for (i = 1; i < NF; i++) if ($i == "-a" || $i == "--add") print $(i+1) }\'`\n'
        postrm += '\t\tbbnote "${PN}: Running groupmems command to add user $username to group $groupname"\n'
        postrm += '\t\tlocal mem_exists="`grep "^$groupname:[^:]*:[^:]*:\\([^,]*,\\)*$username\\(,[^,]*\\)*$" $rootdir/etc/group || true`"\n'
        postrm += '\t\tif test "x$mem_exists" = "x"; then\n'
        postrm += '\t\t\teval flock -x $rootdir${sysconfdir} -c "$PSEUDO groupmems $opts" || true\n'
        postrm += '\t\t\tmem_exists="`grep "^$groupname:[^:]*:[^:]*:\\([^,]*,\\)*$username\\(,[^,]*\\)*$" $rootdir/etc/group || true`"\n'
        postrm += '\t\t\tif test "x$mem_exists" = "x"; then\n'
        postrm += '\t\t\t\tbbfatal "${PN}: groupmems add command did not succeed."\n'
        postrm += '\t\t\tfi\n'
        postrm += '\t\telse\n'
        postrm += '\t\t\tbbnote "${PN}: group $groupname already contains $username, not re-adding it"\n'
        postrm += '\t\tfi\n'
        postrm += '\telif test "x$is_delete" != "x"; then\n'
        postrm += '\t\t# Removing user from group\n'
        postrm += '\t\tlocal username=`echo "$opts" | awk \'{ for (i = 1; i < NF; i++) if ($i == "-d" || $i == "--delete") print $(i+1) }\'`\n'
        postrm += '\t\tbbnote "${PN}: Running groupmems command to remove user $username from group $groupname"\n'
        postrm += '\t\tlocal mem_exists="`grep "^$groupname:[^:]*:[^:]*:\\([^,]*,\\)*$username\\(,[^,]*\\)*$" $rootdir/etc/group || true`"\n'
        postrm += '\t\tif test "x$mem_exists" != "x"; then\n'
        postrm += '\t\t\tif groupmems $opts 2>/dev/null; then\n'
        postrm += '\t\t\t\tbbnote "${PN}: Successfully removed user from group"\n'
        postrm += '\t\t\telse\n'
        postrm += '\t\t\t\tbbwarn "${PN}: groupmems delete command did not succeed."\n'
        postrm += '\t\t\tfi\n'
        postrm += '\t\telse\n'
        postrm += '\t\t\tbbnote "${PN}: group $groupname doesn\'t contain $username, not removing it"\n'
        postrm += '\t\tfi\n'
        postrm += '\telse\n'
        postrm += '\t\tbbwarn "${PN}: groupmems command missing add (-a) or delete (-d) operation"\n'
        postrm += '\tfi\n'
        postrm += '}\n'
        
        # Add cleanup logic - for both removal and upgrade
        postrm += 'if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then\n'
        
        # Generate groupmems commands to remove group memberships
        groupmems_param = d.getVar("GROUPMEMS_PARAM:" + pkg) or ""
        has_cleanup_commands = False
        if groupmems_param:
            for cmd in groupmems_param.split(';'):
                if cmd.strip():
                    # Convert -a to -d for removal
                    removal_cmd = cmd.strip().replace(' -a ', ' -d ').replace('-a ', '-d ')
                    removal_cmd = removal_cmd.replace(' --add ', ' --delete ').replace('--add ', '--delete ')
                    postrm += '\tperform_groupmems "" "%s"\n' % removal_cmd
                    has_cleanup_commands = True
        
        if not has_cleanup_commands:
            postrm += '\t# No group memberships to clean up\n'
            
        postrm += 'fi\n'
        d.setVar('pkg_postrm:%s' % pkg, postrm)

        # RDEPENDS setup
        rdepends = d.getVar("RDEPENDS:%s" % pkg) or ""
        rdepends += ' ' + d.getVar('MLPREFIX', False) + 'base-passwd'
        rdepends += ' ' + d.getVar('MLPREFIX', False) + 'shadow'
        # base-files is where the default /etc/skel is packaged
        rdepends += ' ' + d.getVar('MLPREFIX', False) + 'base-files'
        d.setVar("RDEPENDS:%s" % pkg, rdepends)

    # Add the user/group preinstall scripts and RDEPENDS requirements
    # to packages specified by USERADD_PACKAGES
    if not bb.data.inherits_class('nativesdk', d) \
        and not bb.data.inherits_class('native', d):
        useradd_packages = d.getVar('USERADD_PACKAGES') or ""
        for pkg in useradd_packages.split():
            update_useradd_package(pkg)
}

# Use the following to extend the useradd with custom functions
USERADDEXTENSION ?= ""

inherit_defer ${USERADDEXTENSION}
