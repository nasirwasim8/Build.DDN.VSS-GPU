module.exports = {
  apps: [
    {
      name: "ddn-vss-backend",
      script: "/home/nwasim/projects/Build.DDN.Semantic_Search/backend/venv/bin/uvicorn",
      args: "main:app --host 0.0.0.0 --port 8001 --workers 1",
      cwd: "/home/nwasim/projects/Build.DDN.Semantic_Search/backend",
      interpreter: "none",
      env: {
        PYTHONUNBUFFERED: "1",
        INFINIA_ACCESS_KEY: "ISW6U6J6Q1DHHNAWLD8Q",
        INFINIA_SECRET_KEY: "dYeTZybacv3Wgd6mTecL9vdJ3hRJ75MWko2Zq1UL",
        INFINIA_BUCKET: "ddn-intelligent-bucket-01",
        INFINIA_ENDPOINT: "https://192.168.147.129:8111",
        INFINIA_REGION: "us-east-1"
      },
      autorestart: true,
      max_restarts: 10
    },
    {
      name: "ddn-vss-frontend",
      script: "npx",
      args: "vite --host 0.0.0.0 --port 5175",
      cwd: "/home/nwasim/projects/Build.DDN.Semantic_Search/frontend",
      interpreter: "none",
      autorestart: true
    }
  ]
};
