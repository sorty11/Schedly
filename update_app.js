const fs = require('fs');
let app = fs.readFileSync('server/src/app.ts', 'utf8');

// Remove routes
app = app.replace("import notificationRoutes from './routes/notification.routes';\\n", "");
app = app.replace("app.use('/api', notificationRoutes);\\n", "");

// Update /health
const healthRoute = `
app.get('/health', async (req, res) => {
  try {
    const stats = worker.getStats();
    res.status(200).json({
      status: 'ok',
      worker: worker.isRunning() ? 'running' : 'stopped',
      firebase: 'connected',
      pending: stats.pending,
      processedToday: stats.processedToday,
      failedToday: stats.failedToday,
      uptime: process.uptime() + 's'
    });
  } catch(e) {
    res.status(500).json({ status: 'error', message: 'Failed to fetch health' });
  }
});
`;

app = app.replace(/app\.get\('\/health'[\s\S]*?\}\);/m, healthRoute);

fs.writeFileSync('server/src/app.ts', app);
console.log('Updated app.ts');
