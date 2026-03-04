using System;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Media3D;

namespace Wpf3DTutorial;

public partial class MainWindow : Window
{
    // 카메라 궤도 파라미터
    // Camera orbit parameters
    private double _distance = 8.0;
    private double _theta = 0.8;   // 수평 각도 / Horizontal angle
    private double _phi = 0.5;     // 수직 각도 / Vertical angle
    private Point3D _lookAt = new(0, 0, 0); // 패닝 타겟 / Pan target

    private Point _lastMousePos;
    private bool _isRotating;
    private bool _isPanning;

    // 자동 회전용 / For auto-rotation
    private AxisAngleRotation3D _autoRotation = null!;

    public MainWindow()
    {
        InitializeComponent();
        BuildScene();
        UpdateCamera();
    }

    // ============================================================
    // 씬 구성 / Scene construction
    // ============================================================
    private void BuildScene()
    {
        var sceneGroup = new Model3DGroup();

        // (1) 큐브 — 면마다 다른 색상 (텍스처 적용)
        // (1) Cube — different color per face (texture applied)
        var cubeGroup = new Model3DGroup();
        AddCubeFaces(cubeGroup);

        // 자동 회전 Transform 연결
        // Attach auto-rotation transform
        _autoRotation = new AxisAngleRotation3D(new Vector3D(0, 1, 0), 0);
        cubeGroup.Transform = new RotateTransform3D(_autoRotation);
        sceneGroup.Children.Add(cubeGroup);

        // (2) 구 / Sphere
        var sphere = CreateSphere(
            center: new Point3D(3, 0, 0),
            radius: 0.8,
            stacks: 20,
            slices: 20);
        sphere.Material = new DiffuseMaterial(
            new SolidColorBrush(Color.FromRgb(166, 227, 161)));
        sphere.BackMaterial = new DiffuseMaterial(Brushes.DarkGreen);
        sceneGroup.Children.Add(sphere);

        // (3) 원기둥 / Cylinder
        var cylinder = CreateCylinder(
            center: new Point3D(-3, 0, 0),
            radius: 0.6,
            height: 2.0,
            sides: 24);
        cylinder.Material = new DiffuseMaterial(
            new SolidColorBrush(Color.FromRgb(250, 179, 135)));
        cylinder.BackMaterial = new DiffuseMaterial(Brushes.OrangeRed);
        sceneGroup.Children.Add(cylinder);

        // (4) 바닥면 / Floor plane
        var floor = CreateFloor();
        sceneGroup.Children.Add(floor);

        sceneVisual.Content = sceneGroup;
    }

    // ============================================================
    // 큐브 면별 색상 / Cube face colors
    // ============================================================
    private static void AddCubeFaces(Model3DGroup group)
    {
        // 6면 정의: (4개 정점, 색상)
        // 6 faces definition: (4 vertices, color)
        (Point3D[] verts, Color color)[] faces =
        [
            // 앞면(+Z) / Front
            ([new(-1, -1,  1), new( 1, -1,  1), new( 1,  1,  1), new(-1,  1,  1)],
             Color.FromRgb(137, 180, 250)),
            // 뒷면(-Z) / Back
            ([new( 1, -1, -1), new(-1, -1, -1), new(-1,  1, -1), new( 1,  1, -1)],
             Color.FromRgb(203, 166, 247)),
            // 윗면(+Y) / Top
            ([new(-1,  1,  1), new( 1,  1,  1), new( 1,  1, -1), new(-1,  1, -1)],
             Color.FromRgb(243, 139, 168)),
            // 아랫면(-Y) / Bottom
            ([new(-1, -1, -1), new( 1, -1, -1), new( 1, -1,  1), new(-1, -1,  1)],
             Color.FromRgb(148, 226, 213)),
            // 오른면(+X) / Right
            ([new( 1, -1,  1), new( 1, -1, -1), new( 1,  1, -1), new( 1,  1,  1)],
             Color.FromRgb(249, 226, 175)),
            // 왼면(-X) / Left
            ([new(-1, -1, -1), new(-1, -1,  1), new(-1,  1,  1), new(-1,  1, -1)],
             Color.FromRgb(180, 190, 254)),
        ];

        foreach (var (verts, color) in faces)
        {
            var mesh = new MeshGeometry3D();
            foreach (var v in verts)
                mesh.Positions.Add(v);

            // 텍스처 좌표 / Texture coordinates
            mesh.TextureCoordinates.Add(new Point(0, 1));
            mesh.TextureCoordinates.Add(new Point(1, 1));
            mesh.TextureCoordinates.Add(new Point(1, 0));
            mesh.TextureCoordinates.Add(new Point(0, 0));

            mesh.TriangleIndices = new Int32Collection([0, 1, 2, 0, 2, 3]);

            group.Children.Add(new GeometryModel3D
            {
                Geometry = mesh,
                Material = new DiffuseMaterial(new SolidColorBrush(color)),
                BackMaterial = new DiffuseMaterial(
                    new SolidColorBrush(color) { Opacity = 0.5 })
            });
        }
    }

    // ============================================================
    // 구 생성 (UV Sphere) / Sphere generation
    // ============================================================
    private static GeometryModel3D CreateSphere(
        Point3D center, double radius, int stacks, int slices)
    {
        var mesh = new MeshGeometry3D();

        for (int stack = 0; stack <= stacks; stack++)
        {
            double phi = Math.PI * stack / stacks;
            for (int slice = 0; slice <= slices; slice++)
            {
                double theta = 2.0 * Math.PI * slice / slices;
                double x = radius * Math.Sin(phi) * Math.Cos(theta) + center.X;
                double y = radius * Math.Cos(phi) + center.Y;
                double z = radius * Math.Sin(phi) * Math.Sin(theta) + center.Z;
                mesh.Positions.Add(new Point3D(x, y, z));
            }
        }

        for (int stack = 0; stack < stacks; stack++)
        {
            for (int slice = 0; slice < slices; slice++)
            {
                int i = stack * (slices + 1) + slice;
                mesh.TriangleIndices.Add(i);
                mesh.TriangleIndices.Add(i + slices + 1);
                mesh.TriangleIndices.Add(i + 1);

                mesh.TriangleIndices.Add(i + 1);
                mesh.TriangleIndices.Add(i + slices + 1);
                mesh.TriangleIndices.Add(i + slices + 2);
            }
        }

        return new GeometryModel3D { Geometry = mesh };
    }

    // ============================================================
    // 원기둥 생성 / Cylinder generation
    // ============================================================
    private static GeometryModel3D CreateCylinder(
        Point3D center, double radius, double height, int sides)
    {
        var mesh = new MeshGeometry3D();
        double halfH = height / 2.0;

        // 상단/하단 중심 정점
        // Top/bottom center vertices
        mesh.Positions.Add(new Point3D(center.X, center.Y + halfH, center.Z)); // 0: top center
        mesh.Positions.Add(new Point3D(center.X, center.Y - halfH, center.Z)); // 1: bottom center

        // 둘레 정점 (상단 + 하단)
        // Rim vertices (top + bottom)
        for (int i = 0; i <= sides; i++)
        {
            double angle = 2.0 * Math.PI * i / sides;
            double x = radius * Math.Cos(angle) + center.X;
            double z = radius * Math.Sin(angle) + center.Z;
            mesh.Positions.Add(new Point3D(x, center.Y + halfH, z)); // 상단 림 / Top rim
            mesh.Positions.Add(new Point3D(x, center.Y - halfH, z)); // 하단 림 / Bottom rim
        }

        int offset = 2;
        for (int i = 0; i < sides; i++)
        {
            int topA = offset + i * 2;
            int botA = offset + i * 2 + 1;
            int topB = offset + (i + 1) * 2;
            int botB = offset + (i + 1) * 2 + 1;

            // 상단 뚜껑 / Top cap
            mesh.TriangleIndices.Add(0);
            mesh.TriangleIndices.Add(topA);
            mesh.TriangleIndices.Add(topB);

            // 하단 뚜껑 / Bottom cap
            mesh.TriangleIndices.Add(1);
            mesh.TriangleIndices.Add(botB);
            mesh.TriangleIndices.Add(botA);

            // 측면 / Side
            mesh.TriangleIndices.Add(topA);
            mesh.TriangleIndices.Add(botA);
            mesh.TriangleIndices.Add(botB);

            mesh.TriangleIndices.Add(topA);
            mesh.TriangleIndices.Add(botB);
            mesh.TriangleIndices.Add(topB);
        }

        return new GeometryModel3D { Geometry = mesh };
    }

    // ============================================================
    // 바닥면 / Floor plane
    // ============================================================
    private static GeometryModel3D CreateFloor()
    {
        const double size = 6.0;
        var mesh = new MeshGeometry3D();
        mesh.Positions.Add(new Point3D(-size, -1.01, -size));
        mesh.Positions.Add(new Point3D( size, -1.01, -size));
        mesh.Positions.Add(new Point3D( size, -1.01,  size));
        mesh.Positions.Add(new Point3D(-size, -1.01,  size));
        mesh.TriangleIndices = new Int32Collection([0, 1, 2, 0, 2, 3]);

        return new GeometryModel3D
        {
            Geometry = mesh,
            Material = new DiffuseMaterial(
                new SolidColorBrush(Color.FromArgb(80, 100, 100, 140))),
            BackMaterial = new DiffuseMaterial(
                new SolidColorBrush(Color.FromArgb(80, 100, 100, 140)))
        };
    }

    // ============================================================
    // 카메라 업데이트 / Camera update
    // ============================================================
    private void UpdateCamera()
    {
        double x = _distance * Math.Cos(_phi) * Math.Cos(_theta);
        double y = _distance * Math.Sin(_phi);
        double z = _distance * Math.Cos(_phi) * Math.Sin(_theta);

        var position = new Point3D(
            _lookAt.X + x,
            _lookAt.Y + y,
            _lookAt.Z + z);

        camera.Position = position;
        camera.LookDirection = _lookAt - position;
    }

    // ============================================================
    // 확대/축소: 마우스 휠 / Zoom: Mouse wheel
    // ============================================================
    private void Viewport_MouseWheel(object sender, MouseWheelEventArgs e)
    {
        _distance -= e.Delta * 0.005;
        _distance = Math.Clamp(_distance, 2.0, 30.0);
        UpdateCamera();
    }

    // ============================================================
    // 회전: 좌클릭 드래그 / Rotation: Left-click drag
    // ============================================================
    private void Viewport_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        _isRotating = true;
        _lastMousePos = e.GetPosition(viewport);
        viewport.CaptureMouse();
    }

    private void Viewport_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        _isRotating = false;
        if (!_isPanning) viewport.ReleaseMouseCapture();
    }

    // ============================================================
    // 패닝: 우클릭 드래그 / Panning: Right-click drag
    // ============================================================
    private void Viewport_MouseRightButtonDown(object sender, MouseButtonEventArgs e)
    {
        _isPanning = true;
        _lastMousePos = e.GetPosition(viewport);
        viewport.CaptureMouse();
    }

    private void Viewport_MouseRightButtonUp(object sender, MouseButtonEventArgs e)
    {
        _isPanning = false;
        if (!_isRotating) viewport.ReleaseMouseCapture();
    }

    // ============================================================
    // 마우스 이동 처리 / Mouse move handler
    // ============================================================
    private void Viewport_MouseMove(object sender, MouseEventArgs e)
    {
        Point pos = e.GetPosition(viewport);
        double dx = pos.X - _lastMousePos.X;
        double dy = pos.Y - _lastMousePos.Y;
        _lastMousePos = pos;

        if (_isRotating)
        {
            _theta -= dx * 0.01;
            _phi += dy * 0.01;
            _phi = Math.Clamp(_phi, -1.55, 1.55);
            UpdateCamera();
        }
        else if (_isPanning)
        {
            // 카메라의 로컬 좌표계 기준으로 이동
            // Move based on camera's local coordinate system
            var look = camera.LookDirection;
            look.Normalize();

            var up = camera.UpDirection;
            var right = Vector3D.CrossProduct(look, up);
            right.Normalize();
            up = Vector3D.CrossProduct(right, look);
            up.Normalize();

            double panSpeed = _distance * 0.002;
            _lookAt += right * (-dx * panSpeed) + up * (dy * panSpeed);
            UpdateCamera();
        }
    }

    // ============================================================
    // 자동 회전 애니메이션 / Auto-rotation animation
    // ============================================================
    private void AutoRotate_Checked(object sender, RoutedEventArgs e)
    {
        // DoubleAnimation으로 Angle 속성을 0→360 반복 애니메이션
        // Animate Angle property from 0 to 360 with DoubleAnimation
        var animation = new DoubleAnimation(0, 360, TimeSpan.FromSeconds(6))
        {
            RepeatBehavior = RepeatBehavior.Forever
        };
        _autoRotation.BeginAnimation(
            AxisAngleRotation3D.AngleProperty, animation);
    }

    private void AutoRotate_Unchecked(object sender, RoutedEventArgs e)
    {
        // 애니메이션 중지 / Stop animation
        _autoRotation.BeginAnimation(
            AxisAngleRotation3D.AngleProperty, null);
    }
}
