require('dotenv').config();
const express = require('express');
const cors = require('cors');
const authRouter = require('./auth');
const { router: syncRouter } = require('./sync');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/auth', authRouter);
app.use('/sync', syncRouter);
app.get('/health', (_, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 7000;
app.listen(PORT, () => console.log(`[Server] Running on port ${PORT}`));
