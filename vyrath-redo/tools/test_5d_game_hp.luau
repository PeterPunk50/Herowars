-- Test 5d (Server data model, V58 in Play): dragon HP and state after the attacks.
for _, m in workspace:GetDescendants() do
	if m:IsA("Model") and m.Name == "Vyrath" and m:GetAttribute("State") ~= nil then
		return ("dragon HP %s, state %s, exposed %s"):format(tostring(m:GetAttribute("HP")), tostring(m:GetAttribute("State")), tostring(m:GetAttribute("Exposed")))
	end
end
return "no dragon"
