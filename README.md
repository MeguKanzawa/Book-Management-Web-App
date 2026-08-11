# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Testing Purposes

To run the entire app:

``` bash

rails server

```

To test individual endpoints:

``` bash

rails runner "pp RakutenBooksService.search_parent_series('悲劇の元凶')"

```

## Important Notes

### Filters to Use

- ISBN: Physical: .../9784758099141_1_3.jpg (Starts with 978), .../2100014829920.jpg (Starts with 2100)
- genre_id: Physical Manga / Light Novels: 001001012 (Manga) and 001017006003 (Light Novels), Digital Copy Entries: Both entries in your list that contain (ノベル) and (コミカライズ) have genre_id: "001025002".

<!-- 
Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ... -->
