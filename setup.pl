#!/usr/bin/perl
use strict;
use warnings;
use diagnostics;

use File::Fetch;
use File::Find;
use File::Path;
use File::Copy;
use File::Basename;
use Net::Ping;
use Cwd 'abs_path';
use Env '@PATH';

# Don't display Permission denied errors on find
no warnings 'File::Find';

our $target = "";
our $host = $ENV{HOST};
if (!$host) { $host = "default"; }
my $target_instructions;
my $host_instructions;

my $syscmd_privileged;

my $syscmd_reboot;

my @syscmd_install_package;

my $sys_install_nix;
my $sys_install_nix_as_package;
my $sys_install_nix_package;
my $sys_install_nix_with_daemon;
my @sys_nix_packages;

my $sys_install_flatpak;
my $sys_install_flatpak_package;
my @sys_flatpak_packages;

my @sys_packages;

my @sys_nerd_fonts_packages;
my @sys_enable_dm;

my $installation_part;

my @progress;
my $progress_read = 0;

my @browser_extensions;

sub step
{
    my ($name, $id) = @_;

    if ($id eq "") 
    {
        unless ($name eq "") { printf("[*] $name\n") };
        return 
    };

    if ($progress_read == 0 && -e "$ENV{HOME}/.local/share/dotfile_progress")
    {
        unless (-d "$ENV{HOME}/.local") { mkdir("$ENV{HOME}/.local") }
        unless (-d "$ENV{HOME}/.local/share") { mkdir("$ENV{HOME}/.local/share") }

        my $filename = "$ENV{HOME}/.local/share/dotfile_progress";
        open my $fh, '<', $filename or die "Could not open $filename for reading: $!";
        my $contents = do { local $/; <$fh> };

        @progress = split("\n", $contents);
        close($fh);

        $progress_read = 1;
    }

    foreach (@progress)
    {
        if ($_ eq $id) {
            return 0;
        };
    }

    unless ($name eq "") { printf("[*] $name\n") };
    return 1;
}

sub write_progress 
{
    my ($id) = @_;

    if ($progress_read == 0 && -e "$ENV{HOME}/.local/share/dotfile_progress")
    {
        unless (-d "$ENV{HOME}/.local") { mkdir("$ENV{HOME}/.local") }
        unless (-d "$ENV{HOME}/.local/share") { mkdir("$ENV{HOME}/.local/share") }

        my $filename = "$ENV{HOME}/.local/share/dotfile_progress";
        open my $fh, '<', $filename or die "Could not open $filename for reading: $!";
        my $contents = do { local $/; <$fh> };

        @progress = split("\n", $contents);
        close($fh);

        $progress_read = 1;
    }

    unless ($id eq "") { push(@progress, $id) };
    
    unless (-d "$ENV{HOME}/.local") { mkdir("$ENV{HOME}/.local") }
    unless (-d "$ENV{HOME}/.local/share") { mkdir("$ENV{HOME}/.local/share") }
    open(my $progress_file, '>', "$ENV{HOME}/.local/share/dotfile_progress") or die($!);
    foreach (@progress) { print $progress_file ("$_\n"); }
    close($progress_file);
}

sub replace_in_file
{
	my ($file, $replace, $with) = @_;

	open(my $in, '<:encoding(UTF-8)', $file) or die("Could not open '$file' for reading $!");
	local $/ = undef;
	my $all = <$in>;
	close $in;

	$all =~ s/$replace/$with/g;

	open my $out, '>:encoding(UTF-8)', $file or die "Could not open '$file' for writing $!";;
	print $out $all;
	close $out;

	return;
}

sub license_prompt
{
    step('', 'license_prompt') or return;

	my $LICENSE_NOTICE = "THE SOFTWARE IS PROVIDED \"AS IS\" WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.";

	printf("NOTICE:\n %s\n\n", $LICENSE_NOTICE);

	my $accept = "";

	while (!($accept eq 'yes' || $accept eq 'YES'))
	{
		printf("Do you accept the notice (yes/no): ");

		$accept = <STDIN>;
		chomp $accept;

		if ($accept eq 'no' || $accept eq 'NO') { exit(1); }
	}

    write_progress('license_prompt');
}

sub detect_target_linux
{
	open(my $fh, '<', "/etc/os-release") or die("Could not open \"/etc/os-release\"");
	{
		local $/;
		my @target_results = grep(/^ID/, split '\n', <$fh>);
		$target = $target_results[0];
	}	

	$target =~ s/ID=//g;
}

sub detect_target
{
	if (-f "custom.pl")
	{
		$target = "custom.pl";
		return;
	}

	if ($^O eq "linux")
	{
		detect_target_linux();
	}

	if ($^O eq "darwin" || $^O eq "freebsd" || $^O eq "openbsd")
	{
		$target = $^O;
	}

	if (!$target)
	{
		die("Your machine is not supported (yet)!");
	}
}

sub get_target_instructions()
{
	if (!(-f "targets/$target.pl")) { die("Your machine is not supported (yet)!"); }

	open(my $fh, '<', "targets/$target.pl") or die("Could not open \"targets/$target.pl\"");
	{
		local $/;
		$target_instructions = <$fh>;
	}

	close($fh) or die("Could not close \"targets/$target.pl\"");
}

sub get_host_instructions()
{
    if (!(-f "hosts/$host.pl")) { die("Host $host does not exist"); }

    open(my $fh, '<', "hosts/$host.pl") or die("Could not open \"hosts/$host.pl\"");
    {
        local $/;
        $host_instructions = <$fh>;
    }

    close($fh) or die("Could not close \"hosts/$host.pl\"");
}

sub test_network_connection()
{
    step("Testing network connection", '');
    my $p = Net::Ping->new("tcp", 2);
    $p->port_number(scalar(getservbyname("http", "tcp")));
    $p->ping("example.com") or die("Network connection test failed: $!");
    $p->close();
}

sub detect_syscmd_privileged
{
    if (!($syscmd_privileged eq "auto")) { return; }

    foreach ("doas", "sudo")
    {
        my $executable = $_;
        my $exec_exists = grep -x "$_/$executable", @PATH;
        if ($exec_exists)
        {
            $syscmd_privileged = $_;
            return;
        }
    }

    die("You need doas or sudo to continue.");
}

my @nix_leftover;
sub nix_leftover_wanted
{
	return unless -d;
	return unless /^nix-binary-tarball-unpack.*\z/s;
	push @nix_leftover, $File::Find::name;
}

my @nix_install;
sub nix_install_dir
{
	return unless -d;
	push @nix_install, $File::Find::name;
}

my @nix_install_scripts;
sub find_nix_install_scripts
{
	$File::Find::prune = 1 if /store/;
	return unless -f;
	push @nix_install_scripts, $File::Find::name;
}

sub install_nix
{
    my $executable = 'nix';
    my $exec_exists = grep -x "$_/$executable", @PATH;

	if (!$sys_install_nix) { return; }
    if ($exec_exists) { return }

	step("Installing the Nix Package Manager and packages that use it.", 'nix_install') or return;

	if ($sys_install_nix_as_package)
	{
		system($syscmd_privileged, @syscmd_install_package, $sys_install_nix_package);
		if ($?) { die("The system package manager exited with the $? exit code."); }
        write_progress('nix_install');
	}
	else
	{
		my $script = "https://nixos.org/nix/install";
		my $ff = File::Fetch->new(uri => $script);
		my $file = $ff->fetch(to => "/tmp/nix_installer") or die("Failed to download the nix installation script.");

		printf("(Patching /tmp/nix_installer/install to not start the proper installer by itself...)\n");
		replace_in_file('/tmp/nix_installer/install', qr/"\$script" "\$@"/is, '');
		replace_in_file('/tmp/nix_installer/install', qr/trap cleanup EXIT INT QUIT TERM/is, '');

		find(\&nix_leftover_wanted, '/tmp');

		if (@nix_leftover)
		{
			printf("(Removing the leftover nix installer directories:\n");

			foreach (@nix_leftover)
			{
				printf(" $_\n");
				rmtree($_);

			}

			printf(")\n");
		}

		my $accept = "";

		while (!($accept eq 'yes' || $accept eq 'YES' || $accept eq 'no' || $accept eq 'NO'))
		{
			printf("Do you want to preview the nix installation script? (yes/no) ");

			$accept = <STDIN>;
			chomp $accept;
		}

		if ($accept eq 'yes' || $accept eq 'YES')
		{
			printf("\nThe script is stored under /tmp/nix_installer/install. Preview it by using a text editor or pager of your choice. Return to the script by typing `exit`.\nYou can also stop the installation by removing the file and exiting.\n");
			system('sh');
		}

		if (!(-f '/tmp/nix_installer/install')) { printf("Aborting...\n"); exit(1); }

		system('sh', '/tmp/nix_installer/install');
		if ($?) { die("The nix installer exited with the $? exit code."); }

		@nix_leftover = ();
		find(\&nix_leftover_wanted, '/tmp');
		find(\&nix_install_dir, $nix_leftover[0].'/unpack');

		if (!($syscmd_privileged eq 'sudo'))
		{
			printf("(Patching $nix_install[0]/* to use $syscmd_privileged instead of sudo...)\n");
			find(\&find_nix_install_scripts, $nix_install[0]);

			foreach (@nix_install_scripts)
			{
				replace_in_file($_, qr/sudo/in, $syscmd_privileged);
			}

			printf("(Patching $nix_install[1]/install-multi-user to use env HOME instead of HOME");

			replace_in_file("$nix_install[1]/install-multi-user", qr/HOME="\$ROOT_HOME"/in, "env HOME=\"\$ROOT_HOME\"");
		}


		system('env', "PATH=$ENV{PATH}:/sbin", 'sh', $nix_install[1].'/install', ($sys_install_nix_with_daemon ? '--daemon' : '--no-daemon'), '--yes');
		if ($?) { 
            printf("The nix installer died. An install cleanup might be needed.\n To cleanup the installation execute following commands as root:\n - find / -name \".backup-before-nix\" -delete\n - rm -rf /nix\n");
            die("The nix installer exited with the $? exit code."); 
        }

        write_progress('nix_install');
	}
}

sub install_nix_packages
{
    if (!@sys_nix_packages) { return; }
    step("Installing nix packages", "nix_packages") or return;

    system('nix-env', '-i', @sys_nix_packages);
    if ($?) { die("The nix package manager exited with the $? exit code."); }
    write_progress('nix_packages');
}

sub install_flatpak
{
	if (!$sys_install_flatpak) { return; }

	step('Installing flatpak and the packages that use it.', 'flatpak_install') or return;

	system($syscmd_privileged, @syscmd_install_package, $sys_install_flatpak_package);
	if ($?) { die("The system package manager exited with the $? exit code."); }

	system($syscmd_privileged, 'flatpak', 'remote-add', '--if-not-exists', 'flathub', 'https://dl.flathub.org/repo/flathub.flatpakrepo');
	if ($?) { die("The flatpak package manager exited with the $? exit code."); }

	system($syscmd_privileged, 'flatpak', 'install', '--noninteractive', @sys_flatpak_packages);
	if ($?) { die("The flatpak package manager exited with the $? exit code."); }

    write_progress('flatpak_install');
}

sub install_required
{
	if (@sys_packages)
	{
		step('Installing required system packages.', 'system_packages') or return;

		system($syscmd_privileged, @syscmd_install_package, @sys_packages);
		if ($?) { die("The system package manager exited with the $? exit code."); }
        write_progress('system_packages');
	}
}

sub install_fonts
{
	step('Installing nerd-fonts.', 'fonts') or return;

	if (@sys_nerd_fonts_packages)
	{
		system($syscmd_privileged, @syscmd_install_package, @sys_nerd_fonts_packages);
		if ($?) { die("The system package manager exited with the $? exit code."); }
        write_progress('fonts');
	}
	else
	{
		system('git', 'clone', '--depth', '1', 'https://github.com/ryanoasis/nerd-fonts', '/tmp/nerd-fonts');
		if ($?) { die("Git exited with the $? exit code."); }

		system($syscmd_privileged, '/tmp/nerd-fonts/install.sh', '-S');
		if ($?) { die("Nerd-fonts installer exited with the $? exit code."); }
        write_progress('fonts');
	}
}

sub generate_gituser()
{
    step("Generating .gituser.", 'gituser') or return;
    printf("This assistant will help you with setting your git credencials.\n");
    printf("NOTE: You will be able to change these settings by modifing the ~/.gituser file.\n");
    printf("If you don't know what to enter there, enter your system login as the user name, and [system login]@[hostname].localhost as the email\n");

    printf("Please enter your git user name: ");
    my $user = <STDIN>;
    chomp($user);
    printf("Please enter your git email address: ");
    my $email = <STDIN>;
    chomp($email);
    open(my $gituser, '>>', "$ENV{HOME}/.gituser") or die($!);
    print $gituser ("[user]\n\tname = $user\n\temail = $email\n");
    close($gituser);
    write_progress('gituser');
}

sub install_tpm
{
    step("Installing the Tmux package manager", 'tpm') or return;
    system("git", "clone", "https://github.com/tmux-plugins/tpm", "$ENV{HOME}/.tmux/plugins/tpm");
	if ($?) { die("Git exited with the $? exit code."); }
    write_progress('tpm');
}

# WARNING: Some terrible code incoming!
sub install_configs
{
	step('Installing the user configuration files.', '');

    if (-d "$ENV{HOME}/.config")
    {
        my $accept = "";

        while (!($accept eq 'no' || $accept eq 'NO'))
        {
            printf("Do you want to backup the .config directory? (yes/no) ");

            $accept = <STDIN>;
            chomp $accept;

            if ($accept eq 'yes' || $accept eq 'YES') { move("$ENV{HOME}/.config", "$ENV{HOME}/.config.bak") }
        }
    }

    unless (-d "$ENV{HOME}/.config") { mkdir("$ENV{HOME}/.config") }

    # Alacritty
    unless (-d "$ENV{HOME}/.config/alacritty") { mkdir("$ENV{HOME}/.config/alacritty") or die($!); }
    copy('./configs/alacritty/alacritty.yml', "$ENV{HOME}/.config/alacritty/alacritty.yml") or die($!);

    # Cmus
    unless (-d "$ENV{HOME}/.config/cmus") { mkdir("$ENV{HOME}/.config/cmus") or die($!); }
    copy('./configs/cmus/kanagawa.theme', "$ENV{HOME}/.config/cmus/kanagawa.theme") or die($!);
    copy('./configs/cmus/rc', "$ENV{HOME}/.config/cmus/rc") or die($!);

    # Dunst
    unless (-d "$ENV{HOME}/.config/dunst") { mkdir("$ENV{HOME}/.config/dunst") or die($!); }
    copy('./configs/dunst/dunstrc', "$ENV{HOME}/.config/dunst/dunstrc") or die($!);

    # i3 and i3status
    unless (-d "$ENV{HOME}/.config/i3") { mkdir("$ENV{HOME}/.config/i3") or die($!); }
    unless (-d "$ENV{HOME}/.config/i3status") { mkdir("$ENV{HOME}/.config/i3status") or die($!); }
    copy('./configs/i3/config', "$ENV{HOME}/.config/i3/config") or die($!);
    copy('./configs/i3/volume_brightness.sh', "$ENV{HOME}/.config/i3/volume_brightness.sh") or die($!);
    copy('./configs/i3status/config', "$ENV{HOME}/.config/i3status/config") or die($!);

    # Neovim
    unless (-d "$ENV{HOME}/.config/nvim") { mkdir("$ENV{HOME}/.config/nvim") or die($!); }
    unless (-d "$ENV{HOME}/.config/nvim/lua") { mkdir("$ENV{HOME}/.config/nvim/lua") or die($!); }
    unless (-d "$ENV{HOME}/.config/nvim/lua/plugins") { mkdir("$ENV{HOME}/.config/nvim/lua/plugins") or die($!); }
    unless (-d "$ENV{HOME}/.config/nvim/after") { mkdir("$ENV{HOME}/.config/nvim/after") or die($!); }
    unless (-d "$ENV{HOME}/.config/nvim/after/plugin") { mkdir("$ENV{HOME}/.config/nvim/after/plugin") or die($!); }
    copy('./configs/nvim/init.lua', "$ENV{HOME}/.config/nvim/init.lua") or die($!);
    copy('./configs/nvim/lua/plugins/webicons.lua', "$ENV{HOME}/.config/nvim/lua/plugins/webicons.lua") or die($!);
    copy('./configs/nvim/lua/plugins/telescope.lua', "$ENV{HOME}/.config/nvim/lua/plugins/telescope.lua") or die($!);
    copy('./configs/nvim/lua/plugins/harpoon.lua', "$ENV{HOME}/.config/nvim/lua/plugins/harpoon.lua") or die($!);
    copy('./configs/nvim/lua/plugins/treesitter.lua', "$ENV{HOME}/.config/nvim/lua/plugins/treesitter.lua") or die($!);
    copy('./configs/nvim/lua/plugins/undotree.lua', "$ENV{HOME}/.config/nvim/lua/plugins/undotree.lua") or die($!);
    copy('./configs/nvim/lua/plugins/lsp.lua', "$ENV{HOME}/.config/nvim/lua/plugins/lsp.lua") or die($!);
    copy('./configs/nvim/lua/plugins/oil.lua', "$ENV{HOME}/.config/nvim/lua/plugins/oil.lua") or die($!);
    copy('./configs/nvim/lua/plugins/colorscheme.lua', "$ENV{HOME}/.config/nvim/lua/plugins/colorscheme.lua") or die($!);
    copy('./configs/nvim/lua/plugins/whichkey.lua', "$ENV{HOME}/.config/nvim/lua/plugins/whichkey.lua") or die($!);
    copy('./configs/nvim/lua/plugins/gitsigns.lua', "$ENV{HOME}/.config/nvim/lua/plugins/gitsigns.lua") or die($!);
    copy('./configs/nvim/lua/plugins/tmux.lua', "$ENV{HOME}/.config/nvim/lua/plugins/tmux.lua") or die($!);
    copy('./configs/nvim/lua/plugins/leap.lua', "$ENV{HOME}/.config/nvim/lua/plugins/leap.lua") or die($!);
    copy('./configs/nvim/lua/plugins/textobjects.lua', "$ENV{HOME}/.config/nvim/lua/plugins/textobjects.lua") or die($!);
    copy('./configs/nvim/lua/plugins/lualine.lua', "$ENV{HOME}/.config/nvim/lua/plugins/lualine.lua") or die($!);
    copy('./configs/nvim/lua/plugins/dashboard.lua', "$ENV{HOME}/.config/nvim/lua/plugins/dashboard.lua") or die($!);
    copy('./configs/nvim/lua/plugins/comment.lua', "$ENV{HOME}/.config/nvim/lua/plugins/comment.lua") or die($!);
    copy('./configs/nvim/lua/plugins/icons.lua', "$ENV{HOME}/.config/nvim/lua/plugins/icons.lua") or die($!);
    copy('./configs/nvim/lua/package_manager.lua', "$ENV{HOME}/.config/nvim/lua/package_manager.lua") or die($!);
    copy('./configs/nvim/lua/remap.lua', "$ENV{HOME}/.config/nvim/lua/remap.lua") or die($!);
    copy('./configs/nvim/lua/settings.lua', "$ENV{HOME}/.config/nvim/lua/settings.lua") or die($!);
    copy('./configs/nvim/after/plugin/harpoon.lua', "$ENV{HOME}/.config/nvim/after/plugin/harpoon.lua") or die($!);
    copy('./configs/nvim/after/plugin/telescope.lua', "$ENV{HOME}/.config/nvim/after/plugin/telescope.lua") or die($!);
    copy('./configs/nvim/after/plugin/undotree.lua', "$ENV{HOME}/.config/nvim/after/plugin/undotree.lua") or die($!);
    copy('./configs/nvim/after/plugin/leap.lua', "$ENV{HOME}/.config/nvim/after/plugin/leap.lua") or die($!);
    copy('./configs/nvim/after/plugin/treesitter.lua', "$ENV{HOME}/.config/nvim/after/plugin/treesitter.lua") or die($!);
    copy('./configs/nvim/after/plugin/lsp.lua', "$ENV{HOME}/.config/nvim/after/plugin/lsp.lua") or die($!);
    copy('./configs/nvim/after/plugin/lualine.lua', "$ENV{HOME}/.config/nvim/after/plugin/lualine.lua") or die($!);
    copy('./configs/nvim/after/plugin/colorscheme.lua', "$ENV{HOME}/.config/nvim/after/plugin/colorscheme.lua") or die($!);
    copy('./configs/nvim/after/plugin/textobjects.lua', "$ENV{HOME}/.config/nvim/after/plugin/textobjects.lua") or die($!);
    copy('./configs/nvim/after/plugin/comment.lua', "$ENV{HOME}/.config/nvim/after/plugin/comment.lua") or die($!);
    copy('./configs/nvim/after/plugin/icons.lua', "$ENV{HOME}/.config/nvim/after/plugin/icons.lua") or die($!);
    copy('./configs/nvim/after/plugin/gitsigns.lua', "$ENV{HOME}/.config/nvim/after/plugin/gitsigns.lua") or die($!);
    copy('./configs/nvim/after/plugin/oil.lua', "$ENV{HOME}/.config/nvim/after/plugin/oil.lua") or die($!);
    copy('./configs/nvim/after/plugin/dashboard.lua', "$ENV{HOME}/.config/nvim/after/plugin/dashboard.lua") or die($!);

    # Rofi
    unless (-d "$ENV{HOME}/.config/rofi") { mkdir("$ENV{HOME}/.config/rofi") or die($!) };
    copy('./configs/rofi/config.rasi', "$ENV{HOME}/.config/rofi/config.rasi") or die($!);
    copy('./configs/rofi/kanagawa.rasi', "$ENV{HOME}/.config/rofi/kanagawa.rasi") or die($!);

    # Gitconfig
    copy('./configs/_gitconfig', "$ENV{HOME}/.gitconfig") or die($!);

    # Starship
    copy('./configs/starship.toml', "$ENV{HOME}/.config/starship.toml") or die($!);

    # Xinit
    copy('./configs/_xinitrc', "$ENV{HOME}/.xinitrc") or die($!);

    # Tmux
    unless (-d "$ENV{HOME}/.config/tmux") { mkdir("$ENV{HOME}/.config/tmux") or die($!) };
    copy('./configs/tmux/tmux.conf', "$ENV{HOME}/.config/tmux/tmux.conf") or die($!);

    # Wallpaper
    copy('./configs/wall.png', "$ENV{HOME}/.bitmap.png") or die($!);

    # Append the startx script to bash profile
    open(my $bash_profile, '>>', "$ENV{HOME}/.bash_profile") or die($!);
    print $bash_profile ("[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec startx\n");
    close($bash_profile);

    # Append the part2 autostart to i3
    open(my $i3conf, '>>', "$ENV{HOME}/.config/i3/config") or die($!);
    printf $i3conf ("\nfor_window [class=\"DotfileSetup\"], floating enable\nexec --no-startup-id alacritty --command %s --class DotfileSetup\n", abs_path($0));
    close($i3conf);
}

sub install_configs_step2
{
	step('Installing the user configuration files (part2).', '');
    # Fish
    unless (-d "$ENV{HOME}/.config/fish") { mkdir("$ENV{HOME}/.config/fish") or die($!); }
    unless (-d "$ENV{HOME}/.config/fish/completions") { mkdir("$ENV{HOME}/.config/fish/completions") or die($!); }
    unless (-d "$ENV{HOME}/.config/fish/conf.d") { mkdir("$ENV{HOME}/.config/fish/conf.d") or die($!); }
    unless (-d "$ENV{HOME}/.config/fish/functions") { mkdir("$ENV{HOME}/.config/fish/functions") or die($!); }
    copy('./configs/fish/config.fish', "$ENV{HOME}/.config/fish/config.fish") or die($!);
    copy('./configs/fish/fish_variables', "$ENV{HOME}/.config/fish/fish_variables") or die($!);

    # Bash
    copy('./configs/_bashrc', "$ENV{HOME}/.bashrc") or die($!);

    # Remove setup autostart from i3
    copy('./configs/i3/config', "$ENV{HOME}/.config/i3/config") or die($!);
}

sub is_librewolf_running { `pgrep librewolf` ? 1 : 0 }

sub set_up_librewolf
{
	step("Setting up Librewolf", "librewolf") or return;
	if (is_librewolf_running()) { printf("Close all librewolf windows to continue\n") };
	while (is_librewolf_running()) { };

	printf("%s%s%s", "An librewolf instance will be opened at workspace 2 (switch workspaces by using SUPER(WIN)+(Workspace)).\n",
	       "First at the about:config (Advanced Preferences) page search up \"toolkit.legacyUserProfileCustomizations.stylesheets\" and set it to true by double clicking on it.\n",
	       "After it go to the about:support page (Troubleshooting Information) and copy the Profile Directory (after .librewolf/) and paste it here (ex. xxxxxxxx.default-default): ");

    my $librewolf_pid = fork();
	die if not defined $librewolf_pid;
	if ($librewolf_pid == 0) { `flatpak run io.gitlab.librewolf-community about:support 2>/dev/null`; exit(0) };

    sleep 2;
	`flatpak run io.gitlab.librewolf-community --new-tab about:config 2>/dev/null`;
	my $profile = "";
	while ($profile eq "")
	{
		$profile = <STDIN>;
		chomp($profile);
	}

	foreach (@browser_extensions)
	{
		`flatpak run io.gitlab.librewolf-community --new-tab addons.mozilla.org/en-US/firefox/addon/$_ 2>/dev/null`;
	}

	printf("Now check all newly opened tabs, and install extensions from them. <Press ENTER to continue>");
	<STDIN>;
	printf("Go to sideberry settings (Gear icon on the side bar) and change the following settings:\n Navigation bar -> Layout = hidden \n Tabs preview -> Show tab preview on mouse hover = on \n Tabs preview -> Preview mode = popup in page \n Tabs preview -> Fallback mode = in sidebar after the tab \n Tabs preview -> Sidebar side = right \n Appearance -> Density = relaxed \n <Press ENTER to continue>");
	<STDIN>;
	printf("Click on \"Tabs\" text in the sidebar header and press \"Move sidebar to the right\". <Press ENTER to continue>");
	<STDIN>;
	printf("Right click on the url bar and press \"Customize toolbar\". Right click on all extensions on the toolbar and uncheck \"Pin to toolbar\".\n Remove the Padding surrounding the url bar, right click on the download icon and select \"Hide when empty\" and move it to the left. <Press ENTER to continue>");
	<STDIN>;
	printf("Close the librewolf window to continue the installation.\n");

    unless (-d "$ENV{HOME}/.var/app/io.gitlab.librewolf-community/.librewolf/$profile/chrome") { mkdir("$ENV{HOME}/.var/app/io.gitlab.librewolf-community/.librewolf/$profile/chrome") }
	copy("./configs/userChrome.css", "$ENV{HOME}/.var/app/io.gitlab.librewolf-community/.librewolf/$profile/chrome/userChrome.css") or die($!);
	
    wait();
    write_progress("librewolf");
}

sub set_up_autorandr
{
	step("Setting up autorandr", "autorandr") or return;

	my $arandr = fork();
	die if not defined $arandr;
	if ($arandr == 0) {`arandr 2>/dev/null`; exit };

	printf("Autorandr lets you automatically select a display configuration based on currently connected hardware.\n");
	printf("To set up autorandr, change the display configuration, connect additional displays and save the current configuration by typing a name for it.\n");
	printf("When a display will be connected autorandr will automaticaly change the display settings.\n");
	printf("type `done` to close out of the autoradnr setup wizard.\n");
	printf("Not saving any configurations will result in the current one being used.\n");

	while (1)
	{
		printf("> ");
		my $profile = <STDIN>;
		chomp($profile);
		if ($profile eq "done" || $profile eq "DONE") { last };
		system("autorandr", "-s", $profile);
		if ($?) { die("Autorandr exited with the $? exit code."); }
	}

	printf("<Close the resolution settings to continue setup...>\n");
	wait();
    write_progress("autorandr");
}

sub set_up_tmux
{
	step("Installing tmux plugins", "tmux_plugins") or return;

	system("$ENV{HOME}/.tmux/plugins/tpm/bin/install_plugins all");
	if ($?) { die("Tpm exited with the $? exit code."); }
    write_progress("tmux_plugins");
}

sub set_up_nvim
{
    step("Initlaizing Neovim", "nvim") or return;

    printf("Neovim initialization involves three steps:\n");
    printf("  - Installing plugins (Progress displayed in the window opened on startup (can be closed by using :q)\n");
    printf("  - Installing treesitter backends (Progress displayed at the bottom of the screen\n");
    printf("  - Installing lsp servers (Progress displayed in :Mason and at the bottom of the screen)\n");
    printf("\nAfter these steps are done you can close Neovim by entering :q\n");
    printf("<Press ENTER to continue>");
    <STDIN>;

    system("nvim");
    write_progress("nvim");
}

if (!$<)
{
	printf("Do not run this script as root!");
	exit(1);

}

# Preparation
chdir(dirname($0));
unless ($0 eq "./setup.pl") { printf("[Corrected the working directory to %s]\n", dirname($0)) };

license_prompt();
unless ($ENV{BYPASS_NETWORK_TEST}) { test_network_connection(); }
detect_target();
get_target_instructions();
get_host_instructions();

eval $target_instructions;
eval $host_instructions;

detect_syscmd_privileged();

if (!(step('', 'part2')))
{
    my $accept = "";

    while (!($accept eq 'yes' || $accept eq 'YES'))
    {
        printf("Dotfiles were succesfuly installed, do you want to recopy them? (yes/no) ");

        $accept = <STDIN>;
        chomp $accept;

        if ($accept eq 'no' || $accept eq 'NO') { exit(0); }
    }

    install_configs();
    install_configs_step2();
    exit(0);
}

if (step('', 'part1'))
{
    # Installation
    install_nix();
    install_flatpak();
    install_required();
    install_fonts();
    generate_gituser();
    install_tpm();
    install_configs();

    write_progress("part1");
    printf("Part 1 of the instalation is done!\n Reboot your system and login into TTY1 (or by selecting the i3 session in the display manager if you have it installed) to continue.");

    my $accept = "";

    while (!($accept eq 'yes' || $accept eq 'YES'))
    {
        printf("Do you want to reboot now? (yes/no) ");

        $accept = <STDIN>;
        chomp $accept;

        if ($accept eq 'no' || $accept eq 'NO') { exit(0); }
    }

    system($syscmd_reboot);
    exit(0);
}

sub set_up_rustup
{
    step("Setting up rust", "rustup");

    system("rustup", "default", "stable");

    write_progress("rustup");
}

sub set_up_opam
{
    step("Setting up ocaml", "opam");

    printf("(Opam is already configured in the system shells, choose no at the shell configuration screen.)\n");
    system("opam", "init");

    write_progress("opam");
}

install_nix_packages();
set_up_autorandr();
set_up_librewolf(); 
set_up_tmux();
set_up_rustup();
set_up_opam();
set_up_nvim();
install_configs_step2();
write_progress("part2");

printf("Congratulations! The system configuration was successfuly installed (no reboot is required).\n");
printf("<Press ENTER to exit>\n");
<STDIN>;
