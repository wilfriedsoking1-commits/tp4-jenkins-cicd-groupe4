const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.status(200).json({
    status: 'OK',
    version: '1.0.1',
    group: 'ITT3-IR Groupe 4',
    message: 'Pipeline CI/CD Jenkins + Docker opérationnel ! (v1.0.1)'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

if (require.main === module) {
  app.listen(PORT, () => console.log(`Serveur démarré sur le port ${PORT}`));
}

module.exports = app;
