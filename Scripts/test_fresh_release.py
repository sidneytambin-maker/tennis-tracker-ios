import json
import unittest

from check_fresh_release import check_empty, check_watch_preferences


class FreshReleaseTests(unittest.TestCase):
    def empty(self):
        return {"players": [], "matches": [], "trainingSessions": [], "tournaments": [], "deletedRecordIDs": [],
                "setup": {"coaches": [], "venues": [], "locations": [], "tournamentTemplates": []}}

    def test_fresh_state_is_accepted(self):
        check_empty(self.empty())
        check_watch_preferences({})

    def test_missing_library_table_is_not_treated_as_empty(self):
        data = self.empty()
        data.pop("trainingSessions")
        with self.assertRaises(ValueError): check_empty(data)

    def test_prepopulated_catalogue_is_rejected(self):
        for key in ("coaches", "venues", "locations", "tournamentTemplates"):
            data = self.empty()
            data["setup"][key] = [{"name": "Another tester's entry"}]
            with self.assertRaises(ValueError): check_empty(data)

    def test_derived_venues_or_achievements_cannot_leak(self):
        for key in ("knownVenues", "achievementHistory", "achievementRecords"):
            data = self.empty()
            data[key] = [{"id": "old-record"}]
            with self.assertRaises(ValueError): check_empty(data)

    def test_health_and_pending_activity_state_is_rejected(self):
        for key in ("activeHealthTrainingID", "pendingHealthTrainingIDs", "activeTournamentID", "pendingIntentRoute"):
            with self.assertRaises(ValueError): check_watch_preferences({key: "old-state"})

    def test_watch_queue_allows_only_an_unassociated_empty_handshake(self):
        check_watch_preferences({"queuedWatchCommands": json.dumps({"commands": []}).encode()})
        check_watch_preferences({"queuedWatchCommands": json.dumps({"commands": [{"requestSnapshot": {}}]}).encode()})
        for queue in ({"commands": ["old-command"]}, {"commands": [], "libraryID": "old-library"}):
            with self.assertRaises(ValueError): check_watch_preferences({"queuedWatchCommands": json.dumps(queue).encode()})


if __name__ == "__main__": unittest.main()
