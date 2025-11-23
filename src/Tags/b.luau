return {
	Letterwise = false,
	Attributes = {},
	Apply = function(Label: TextLabel, _: { [string]: string }): { RBXScriptConnection }
		Label.RichText = true
		Label.Text = "<b>" .. Label.Text .. "</b>"
		return {}
	end,
}
