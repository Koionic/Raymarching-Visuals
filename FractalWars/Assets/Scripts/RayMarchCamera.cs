using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

[System.Serializable]
public class RaymarchSphere
{
    public Vector4 transform;
    public Color color;
}

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class RayMarchCamera : SceneViewFilter
{
    [Header("Properites")]
    
    [SerializeField]
    private Shader _shader;

    public Material _raymarchMaterial
    {
        get
        {
            if (!_raymarchMat && _shader)
            {
                _raymarchMat = new Material(_shader);
                _raymarchMat.hideFlags = HideFlags.HideAndDontSave;
            } 
            return _raymarchMat;
        }
    }

    private Material _raymarchMat;

    public Camera _camera
    {
        get
        {
            if(!_cam)
            {
                _cam = GetComponent<Camera>();
            }
            return _cam;
        }
    }

    private Camera _cam;

    [Header("Rendering")]
    
    [Range(1,300)]
    public int maxIterations;
    [Range(0.1f,0.001f)]
    public float accuracy;
    public float _maxDistance;

    [Header("Lighting")]    
    public Transform _directionLight;
    
    public Color LightColor;
    [Range(0f,1f)]
    public float LightIntensity;
    [Range(0f,1f)]
    public float ColorIntensity;

    public Texture envTexture;
    
    [Header("Main Modulus Shape")]
    public Color _mainColor;
    public Vector4 _sphere1;
    public Vector4 _box1;
    public Vector3 _modInterval;

    [Header("Spheres")]
    public RaymarchSphere[] spheres = new RaymarchSphere[3];
        
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!_raymarchMaterial)
        {
            Graphics.Blit(source, destination);
            return;
        }

        _raymarchMaterial.SetMatrix("_CamFrustum", CamFrustum(_camera));
        _raymarchMaterial.SetMatrix("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMaterial.SetFloat("_maxDistance", _maxDistance);
        _raymarchMaterial.SetFloat("_Accuracy", accuracy);
        _raymarchMaterial.SetInteger("_MaxIterations", maxIterations);
        
        _raymarchMaterial.SetColor("_LightCol", LightColor);
        _raymarchMaterial.SetFloat("_LightIntensity", LightIntensity);
        _raymarchMaterial.SetFloat("_ColorIntensity", ColorIntensity);
        
        
        
        _raymarchMaterial.SetVector("_sphere1", _sphere1);
        _raymarchMaterial.SetVector("_LightDir", _directionLight ? _directionLight.forward : Vector3.down);
        _raymarchMaterial.SetColor("_mainColor", _mainColor);
        _raymarchMaterial.SetVector("_box1", _box1);
        _raymarchMaterial.SetVector("_modInterval", _modInterval);


        
        _raymarchMaterial.SetTexture("_envTex", envTexture);
        
        
        _raymarchMaterial.SetVector("_sphereObj1", spheres[0].transform);
        _raymarchMaterial.SetVector("_sphereObj2", spheres[1].transform);
        _raymarchMaterial.SetVector("_sphereObj3", spheres[2].transform);
        
        _raymarchMaterial.SetVector("_sphereColor1", spheres[0].color);
        _raymarchMaterial.SetVector("_sphereColor2", spheres[1].color);
        _raymarchMaterial.SetVector("_sphereColor3", spheres[2].color);

        RenderTexture.active = destination;
        _raymarchMaterial.SetTexture("_MainTex", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        _raymarchMaterial.SetPass(0);
        GL.Begin(GL.QUADS);

        //Bottom Left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);

        //Bottom Right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);

        //Top Right
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);

        //Top Left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    private Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan((cam.fieldOfView * 0.5f) * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TopLeft = (-Vector3.forward - goRight + goUp);
        Vector3 TopRight = (-Vector3.forward + goRight + goUp);
        Vector3 BottomRight = (-Vector3.forward + goRight - goUp);
        Vector3 BottomLeft = (-Vector3.forward - goRight - goUp);

        frustum.SetRow(0, TopLeft);
        frustum.SetRow(1, TopRight);
        frustum.SetRow(2, BottomRight);
        frustum.SetRow(3, BottomLeft);

        return frustum;
    }
}
