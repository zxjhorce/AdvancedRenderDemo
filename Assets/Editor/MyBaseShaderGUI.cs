
using UnityEngine;
using UnityEditor;

public class MyBaseShaderGUI : ShaderGUI
{
   
    static GUIContent staticLabel = new GUIContent();
   
    protected Material target;
    protected MaterialEditor editor;
    MaterialProperty[] properties;

    protected static GUIContent MakeLabel(string text, string tooltip = null)
    {
        staticLabel.text = text;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    protected static GUIContent MakeLabel(MaterialProperty property, string tooltip = null)
    {
        staticLabel.text = property.displayName;
        staticLabel.tooltip = tooltip;
        return staticLabel;
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        this.target = materialEditor.target as Material;
        this.editor = materialEditor;
        this.properties = properties;
     
    }

    protected void RecordAction(string label)
    {
        editor.RegisterPropertyChangeUndo(label);
    }

    protected bool IsKeywordEnabled(string keyword)
    {
        return target.IsKeywordEnabled(keyword);
    }

    protected void SetKeyword(string keyword, bool state)
    {
        if (state)
        {
            foreach (Material m in editor.targets)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in editor.targets)
            {
                m.DisableKeyword(keyword);
            }
        }
    }

    protected MaterialProperty FindProperty(string name)
    {
        return FindProperty(name, properties);
    }
}
