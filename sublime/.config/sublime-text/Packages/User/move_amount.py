import sublime
import sublime_plugin

class MoveAmountCommand(sublime_plugin.TextCommand):
    def run(self, edit, amount=1, **kwargs):
        for _ in range(amount):
            self.view.run_command("move", args=kwargs)
