import React from 'react';
import { useAccount } from 'wagmi';
import { Layout } from './components/layout/Layout';
import { LandingPage } from './pages/LandingPage';
import { DashboardPage } from './pages/DashboardPage';

function App() {
  const { isConnected } = useAccount();

  return (
    <Layout>
      {isConnected ? <DashboardPage /> : <LandingPage />}
    </Layout>
  );
}

export default App;
