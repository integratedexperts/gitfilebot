GitFileBot
==========
**Process multiple repositories at once.**

## Processing sequence
- Checkout repository
- Copy source files from `add` subdirectory and remove files from `remove` subdirectory
- Replace `name` and `machine_name` tokens (see example.process.sh for format)
- Force-push changes to origin
- Open PR if it has not been opened yet. HUB (tool used to communicate with
  GitHub via API) does not support updating descriptions of already opened
  pull requests.

## Requirements
1. Install hub from https://github.com/github/hub
2. Create GitHub API token
3. Create file `$HOME/.config/hub` with the following content:
   ```
   github.com:
   - user: <your username>
     oauth_token: <your token>
     protocol: https
   ```

## Usage
```
cp example.process.sh process.sh
... modify process.sh and adjust values ...
./process.sh
```
