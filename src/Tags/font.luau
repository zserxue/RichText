return {
	Letterwise = false,
	Attributes = { "color" },
	Apply = function(Label: TextLabel, Attributes: { [string]: string }): { RBXScriptConnection }
		local Color = Attributes.color

		local _, _ = pcall(function()
			return Color3.fromHex(Color)
		end)

		local Text = Label.Text

		Label.RichText = true
		Label.Text = `<font color="{Color}">{Text}</font>`

		return {}
	end,
}
