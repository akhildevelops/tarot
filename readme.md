# What's your Tarrot Birth Card ?
![tarrot](resources/tarots/10.png)
Credits:https://labyrinthos.co

It's a simple webservice written from scratch in zig to identify your birth card.

Run the service and get your tarrot birth card in the browser.

### Setup
- Install zig >=0.14.0,<0.15.0 (use [zigverm](https://github.com/AMythicDev/zigverm) similar to nvm to install and manage zig versions)
- Build the server `zig build -Doptimize=ReleaseFast`
- Run it `./zig-out/bin/tarrot`
- Get your tarrot card by running `http://localhost:8086/date/<year>/<month>/<day>` in the browser.
- Example: `http://localhost:8086/date/1999/10/11`
