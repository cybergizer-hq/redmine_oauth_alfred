## Redmine Alfred omniauth

### Available [redmine](https://hub.docker.com/_/redmine) version: `5.0.3`

### Installation

Download the plugin and install required gems:

```console
cd /path/to/redmine/plugins
git clone https://github.com/cybergizer-hq/redmine_oauth_alfred.git
mv redmine_oauth_alfred redmine_alfred
cd /path/to/redmine
bundle install
```

Restart redmine

### Docker Installation

Add the following lines to your `docker-compose.yml`.

```
    volumes:
    - /path/to/redmine/data:/home/redmine/data
```

Restart redmine

### Configuration

* Login as a user with administrative privileges.
* In top menu select "Administration".
* Click "Plugins"
* In plugins list, click "Configure" in the row for "Redmine Alfred plugin"
* Enter Alfred provider URL
* Enter the Сlient ID & Client Secret
* Enable "Oauth authentication"
* Click Apply.
