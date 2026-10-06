# RuboCop cops for rails-principles

Cops for the `rails-principles` skill (`skills/rails-principles/SKILL.md`), in `skills/rails-principles/rubocop/`.

A code reviewer reads for intent and misses shape. These cops check the shape: the parts of the skill a machine can
decide without guessing. Judgment calls (KISS, naming quality, when to extract) stay in the skill for the reviewers.

The engineer agent already runs `bin/rubocop` and fixes every offense, and the orchestrator's CI gate re-runs it, so
a cop that an app loads is enforced with no change to any agent.

## How an app gets them

The cops live in this skill's directory, `skills/rails-principles/rubocop/`, so they travel with the skill that defines
them: `skills/**` is already vendored into every app by `/rails-install` and `/rails-update`, with the same drift
detection, and the cops and the prose can never be at different versions. There is no gem to publish or host.

`/rails-install` runs `bin/rails-team-setup-project`, whose `rubocop` step adds one line to the app's `.rubocop.yml`:

```yaml
inherit_from:
  - ./skills/rails-principles/rubocop/config/default.yml
```

That one file loads the cops, turns on rubocop-rails's `Rails/StrongParametersExpect` (off by default there), and sets
each cop's defaults. The app's own settings win over anything it inherits. The step is idempotent, never rewrites the
file (it inserts a line and re-reads the result, putting the original back if the check fails), and tells you exactly
what to add by hand when `inherit_from` is written inline. To wire an app that is already installed, re-run
`/rails-install`; it is safe to repeat.

Needs `rubocop` 1.72 or newer and `rubocop-rails` (both come with `rubocop-rails-omakase` on a Rails 8 app).

**Adopting it on an existing app turns `bin/rubocop` red** until the findings are fixed or consciously excepted. A new
app starts clean. The installer reports the count.

## What it checks

| Cop | Catches | Config |
|---|---|---|
| `RailsPrinciples/ControllerActions` | A public controller method that is not one of the seven REST actions. A custom action belongs in a nested singular resource controller (`Listings::SyncsController#create`). | `AllowedActions` |
| `RailsPrinciples/FindThroughAssociation` | `Listing.find(params[:id])`. Go through the owner: `current_account.listings.find(params[:id])`. Only lookups by id; email, token and slug lookups have no owner and are left alone. | `Keys` |
| `RailsPrinciples/NoServiceObjects` | A class or module named `...Service` / `...Presenter` / `...Decorator` / `...Form` and so on; a file under `app/services`, `app/decorators`, ...; a plain class whose entry point is `call` / `perform` / `execute` / `run`. | `ForbiddenSuffixes`, `ForbiddenDirectories`, `EntryPointMethods` |
| `RailsPrinciples/ForbiddenGems` | `redis`, `devise`, `rspec`, `factory_bot`, `sidekiq`, `carrierwave`, `draper`, serializer and search gems, each with what to use instead. | `Forbidden` (name: reason), `Allowed` |

### `params.expect` is not a cop of ours, but it is on

`rubocop-rails` 2.29+ already ships `Rails/StrongParametersExpect`, off by default; the inherited config turns it on.
It flags `params.require(:user).permit(...)` and rewrites it to `params.expect(user: [...])`. It also flags
`Model.find(params[:id])` and wants `find(params.expect(:id))`. Its autocorrect is marked unsafe for a real reason:
`expect` is stricter about nested collections. `permit(pets: [:name])` accepts one hash or an array of hashes;
`expect(pets: [:name])` accepts only one, and an array of hashes needs `[[:name]]`. A rewriter cannot tell which a
client sends, so review those by hand (`rubocop -A` applies it; read the diff).

## When a cop is wrong for one line

Disable that line, with the reason, and nothing else:

```ruby
# A public page looks the record up by the token in its URL; nothing owns it.
Document.find(params[:id]) # rubocop:disable RailsPrinciples/FindThroughAssociation
```

The engineer agent is told never to disable a cop to make it pass. That rule is for convenience, not for genuine
exceptions, so an exception needs the reason beside it, where a reviewer sees it. If a cop needs the same
exception in many places, the cop is wrong: change its config or fix the cop.

An exception for a whole project (a gem it truly needs) goes in `.rubocop.yml`, not scattered in code:

```yaml
RailsPrinciples/ForbiddenGems:
  Allowed:
    - redis
```

## Tests

```sh
# from the team repo root
BUNDLE_GEMFILE=test/rubocop/Gemfile bundle install
BUNDLE_GEMFILE=test/rubocop/Gemfile bundle exec rake -f test/rubocop/Rakefile test
```

Minitest, like the apps. RuboCop's own cop-testing helper assumes RSpec, so `test/rubocop/test_helper.rb` carries the
small part that matters: run one cop over a string of source and return the offenses. `test/` is not vendored (only
`agents/`, `commands/`, `skills/` and `bin/` are), so the tests stay in this repo and do not reach apps.
`installer_wiring_test.rb` runs the real installer script against throwaway projects.

## Adding a cop

A cop is worth adding when a reviewer keeps missing something and the rule can be stated as a shape in the code with
almost no false positives. A rule that needs "is this a good name" is not one; leave it in the skill.

1. `skills/rails-principles/rubocop/lib/rubocop/cop/rails_principles/<name>.rb`, then require it in `.../rails_principles_cops.rb`.
2. Its defaults in `skills/rails-principles/rubocop/config/default.yml`.
3. A test file in `test/rubocop/cop/` with the sad paths (what it must flag) and the happy paths (what it must leave alone). The happy paths are
   what stop people turning the cop off.
4. Run it over a real app before shipping it. If more than about one finding in five needs a `rubocop:disable`, the cop is
   wrong.

5. Then `/rails-deploy`, which regenerates `manifest.yml` so `/rails-update` delivers the change to installed apps.
