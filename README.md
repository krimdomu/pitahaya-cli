# CLI Tools for Pitahaya-CMS

With the pitahya cli tools it is possible to export the content of pitahaya-cms
to your local workstation, edit it and upload it again to the server.

Currently it supports 2 file formats:

* plain html
* markdown


## INSTALLATION

At the moment, you need to clone the repository and you also need the Pitahaya::Client::API module.

## USAGE

Initialize a local repository:

```
pitahaya-cli initialize --user admin --password admin --site_name rexify.org --url http://localhost:3000
```

Pull content:

```
pitahaya-cli pull
```

Push content:

```
pitahaya-cli push
```

Status of the local changes:

```
pitahaya-cli status
```


