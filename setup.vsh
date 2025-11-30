import os

is_windows := $if windows {
	true
} $else {
	false
}

is_mac := $if macos {
	true
} $else {
	false
}

is_linux := $if linux {
	true
} $else {
	false
}

sp := if is_windows { "\\" } else { "/" }

dll_ext := if is_windows {
	"dll"
} else if is_mac {
	"dylib"
} else {
	"so"
}

zmq_package_name := "zeromq"

triplet := $if windows && amd64 {
	"x64-windows"
} $else $if windows && arm64 {
	"arm64-windows"
} $else $if macos && x64 {
	"x64-osx"
} $else $if macos && arm64 {
	"arm64-osx"
} $else $if linux && x64 {
	"x64-linux"
} $else $if linux && arm64 {
	"arm64-linux"
} $else {
	$compile_error("Sorry, current os and arch is not supported. If you need, please edit setup.vsh by yourself.")
	""
}

zmq_full_package_name := "${zmq_package_name}:${triplet}"


root_dir := os.dir(os.executable())
os.chdir(root_dir)!

vcpkg_dir := os.join_path(root_dir, "vcpkg")

if !os.is_dir(vcpkg_dir) {
	{
		mut res := os.execute('git --version')
		if res.exit_code != 0 {
			println('git is missing. Please install git first.')
			exit(1)
		}
	}

	println("fetching vcpkg on ${vcpkg_dir} ...")
	{
		mut res := os.execute('git clone --depth=1 https://github.com/microsoft/vcpkg')
		if res.exit_code != 0 {
			println('Failed to clone vcpkg. Giving up.')
			exit(1)
		}
	}
}

os.chdir(vcpkg_dir)!

{
	mut res := os.execute('./vcpkg --version')
	if res.exit_code != 0 {
		println("bootstrapping vcpkg...")

		{
			cmd := if is_windows {
				"./bootstrap-vcpkg.bat"
			} else {
				"./bootstrap-vcpkg.sh"
			}
			mut res2 := os.execute(cmd)
			if res2.exit_code != 0 {
				println('Failed to execute ${cmd}. Giving up.')
				exit(1)
			}
		}
	}
}

{
	mut res := os.execute('./vcpkg --version')
	if res.exit_code != 0 {
		println('Failed to execute ./vcpkg. Giving up.')
		exit(1)
	}
	vcpkg_version_str := res.output.trim_space().split("\n")[0]
	println('vcpkg is installed on ${vcpkg_dir}')
	println('vcpkg version: ${vcpkg_version_str}')
}

{
	mut res := os.execute('./vcpkg list')
	if res.exit_code != 0 {
		println('Failed to execute ./vcpkg list. Giving up.')
		exit(1)
	}
	vcpkg_list := res.output.trim_space()
	
	if !vcpkg_list.contains(zmq_full_package_name) {
		println("installing ${zmq_full_package_name} using vcpkg... (this may take minutes, be patient)")
		mut res2 := os.execute('./vcpkg install ${zmq_full_package_name}')
		if res2.exit_code != 0 {
			println('Failed to execute ./vcpkg install czmq. Giving up.')
			exit(1)
		}
	}
}

{
	mut res := os.execute('./vcpkg list')
	if res.exit_code != 0 {
		println('Failed to execute ./vcpkg list. Giving up.')
		exit(1)
	}
	vcpkg_list := res.output.trim_space()
	
	if !vcpkg_list.contains(zmq_full_package_name) {
		println('Failed to install ${zmq_full_package_name} using vcpkg. Giving up.')
		exit(1)
	}

	println("vcpkg ${zmq_full_package_name} is installed")
}

bin_path := "${root_dir}${sp}vcpkg${sp}packages${sp}${zmq_package_name}_${triplet}${sp}bin"
lib_path := "${root_dir}${sp}vcpkg${sp}packages${sp}${zmq_package_name}_${triplet}${sp}lib"

if is_windows {
	os.execute("copy ${bin_path}${sp}*.dll ${root_dir}${sp}")
	os.execute("copy ${lib_path}${sp}*.lib ${root_dir}${sp}")
	println("")
	println("[NOTE] Please copy ${bin_path}${sp}*.dll and ${lib_path}${sp}*.lib into your execution path before v run (for linker).")
} else if os.exists(bin_path) {
	println("")
	println("[NOTE] Please copy ${bin_path}${sp}*.${dll_ext} into your execution path before v run (for linker).")

	if is_mac {
		println(" or set DYLD_LIBRARY_PATH to it")
	}
}

if is_linux {
	println("")
	println("[NOTE] On linux, please use `v -cc clang` when run program or test.")
}

