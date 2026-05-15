import express from 'express';
import cors from 'cors';
import { addToLedger, verifyReview, getLedger } from './ledger';

const app = express();
app.use(express.json());
app.use(cors());

// Hash banao aur ledger mein add karo
app.post('/hash', (req, res) => {
  try {
    const data = req.body;
    const entry = addToLedger(data);
    res.json({
      success: true,
      hash: entry.hash,
      previousHash: entry.previousHash,
      timestamp: entry.timestamp,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Hash generation failed' });
  }
});

// Review verify karo
app.get('/verify/:reviewId/:hash', (req, res) => {
  const reviewId = parseInt(req.params.reviewId);
  const hash = req.params.hash;
  const isValid = verifyReview(reviewId, hash);
  res.json({ reviewId, isValid });
});

// Poora ledger dekho
app.get('/ledger', (req, res) => {
  res.json(getLedger());
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`Blockchain service running on port ${PORT}`);
});