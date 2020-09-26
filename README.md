# the_hunting
a *cheap* vuln finding robot. Currently in heavy Dev. So please, be careful with it.. Its a violent script if I've ever written one. Nothing is rate limited so you'll probably get IP blocked over it, specifically during gobuster dir if youre not already banned before getting there.
Cheers!

< Huge shoutout to my dude @1efty for his help bringing this script into the 21st century!

https://github.com/1efty https://twitter.com/ONEefty />
# Requirements

* Axiom https://github.com/pry0cc/axiom
* DigitalOcean Account
* Some API keys if you want good results for subdomain enum

# Warning
Slack integration is included.. you need to add some data to aptly named files and you should be off to the races. Mind you, if you set up file upload by filling in the proper data in `./bot_user_oauth_at.txt` and `./slack_channel.txt`, you also need to have the a bot setup with the proper permissions to post files to whatever channel, then invite the bot to that channel. 

Your data is in slacks hands then though, so if you are working within specific privacy and private program scopes, you may need to adjust course accordingly and do some research before you start dumping possibly important data on your targets into slacks servers and therefore the world. Be smart about it.

# Commands
## Axiom
Start your axiom droplet

`axiom-init`

Connect to your axiom droplet

`axiom-ssh <instance> --tmux`

## Set up `the_hunting.sh`

```bash
git clone --recurse-submodules https://github.com/incredincomp/the_hunting.git
cd the_hunting/
``` 

##*How I make it work for me...*##

run --target then wait it out.. then when you get your notification you can just log back on and run `./the_hunting.sh -file ./target/date-time/responsive-domains-80-443.txt` 

:heart: ~@incredincomp

### *THE INSTALL.SH SCRIPT IS SOMEWHAT TESTED, NOW BETTER FORMATTED, AND STILL MAYBE DANGEROUS.. GOOD LUCK*
need sudo for program installs with packaging program

`sudo ./install.sh --install`

## Usage
Recon a root domain name for responsive subdomains

`./the_hunting.sh --target hackerone.com`

Exclude out of scope domains from your recon results before doing recon (leaving you with a clean scope subdomain list)

`./the_hunting.sh --target hackerone.com --exclude support.hackerone.com,go.hacker.one,www.hackeronestatus.com,info.hacker.one,ma.hacker.one`

Scan a CSV list of subdomains from the cli

`./the_hunting.sh --scan sub.domain.com,sue.domain.com,paul.domain.com`

Scan a file list of subdomains seperated by new line

`./the_hunting.sh --file subdomains.txt`

This will run all nuclei templates on your list of targets inside of `subdomains.txt`

`./the-hunting.sh --file-all subdomains.txt`

# To-Do/Upcoming
1. switching to aws, probably cheaper and easier to manage. Able to store data and probably just send some encrypted emails.. *maybe need a domain for that though* ![#34](https://github.com/incredincomp/the_hunting/issues/34) 
2. fixing directory structure/house cleaning ![#30](https://github.com/incredincomp/the_hunting/issues/30)


# Methodology

![](https://github.com/incredincomp/usage-videos/blob/master/the_hunting1.PNG)

_Anything crossed out currently is implemented to a point, but turned off in the production version. Manually uncomment them in the script if you want to use them_

## Recon

### Subdomains

#### Subdomain Enum
~~gobuster - vhost & dns
https://github.com/OJ/gobuster~~

~~Amass~~
~~https://github.com/OWASP/Amass~~

Subfinder
https://github.com/projectdiscovery/subfinder

#### Subdomain TakeOver
Subjack
https://github.com/haccer/subjack

### Target Validation

#### Webserver Status Checks
Httprobe
https://github.com/tomnomnom/httprobe

#### Webpage Validation
aquatone
https://github.com/michenriksen/aquatone

## Scanning

### Fuzzing
#### Directory and file Fuzzing
to-do: Dirb
~~https://tools.kali.org/web-applications/dirb~~

~~Gobuster - dir
https://github.com/OJ/gobuster~~

### Port Scanning
#### To-do: nmap

##### usage

##### nse scripts

~~https://nmap.org/book/nse.html~~

### Webpage and Server Scanning

#### nuclei

##### Templates

Community templates - https://github.com/projectdiscovery/nuclei-templates

To-Do: User made templates - https://nuclei.projectdiscovery.io/templating-guide/

##### usage
