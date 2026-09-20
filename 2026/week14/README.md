# Week 14

## 14 September

install garuda linux sway. some keys are not working, trying to fix

## 15 September

sadservers:(

## 16 September

sadservers, bought claude pro

## 17 September

today i starting conspect more tasks for better resumeability of knowluage(because of claude advice)

ok now im trying to remember my todays sadserver practice.

it was working on ["Alexandria": The Vanishing Backups](https://sadservers.com/scenario/alexandria)

7 attempts. it was new for me. i completly fogot about cron and crontab (6 mounths of doing almost nothing)

**key fixes and commands:**

- __cron__ - is a schedule manager for regular commands
- `sudo systemctl status cron` - cron status
- `sudo crontab -l` - to see this schedule
- `sudo crontab -e` - to edit this

my main problem in this scenario was that i not mentiod that in crontab was old script. and next i need to remove .lock file.

## 19 september

Docker review

## 20 september

completed ["Rio de Janeiro": Do we have another option?](https://sadservers.com/scenario/rio) in a first try !

**key fixes and commands:**

- sudo systemctl start jenkins
- sudo systemctl status jenkins.service
- sudo journalctl -u jenkins -n 50 --no-pager
- sudo systemctl enable jenkins.service
- sudo apt update
- ls /usr/lib/jvm
- java -version

problem was incorrect java version

__answer:__

- sudo apt install temurin-11-jdk
- sudo update-alternatives --config java

how to see where jenkins java:

- systemctl cat jenkins
- readlink -f /usr/bin/java
- update-alternatives --display java