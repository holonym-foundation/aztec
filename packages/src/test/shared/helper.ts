async function fetchSignature(actionId: string | number, userAddress: string) {
  const resp = await fetch(`https://api.holonym.io/attestation/sbts/clean-hands?action-id=${actionId}&address=${userAddress}`);
  const { isUnique, signature, circuitId } = await resp.json();
  return { isUnique, signature, circuitId };
}

export { fetchSignature };